# frozen_string_literal: true

require_relative "../../lib/fcs"
require "json"
require "tmpdir"
require "csv"

RSpec.describe "CSV reconciliation" do
  def run_with(input:)
    Dir.mktmpdir do |dir|
      input_path = File.join(dir, "input.json")
      File.write(input_path, JSON.pretty_generate(input))

      out_dir = File.join(dir, "out")
      runner = FCS::Application::Runner.new
      json_path = runner.run!(input_path: input_path, output_dir: out_dir, fee_enabled: true)

      yield(
        json_path: json_path,
        positions_path: File.join(out_dir, "positions.csv"),
        pnl_path: File.join(out_dir, "pnl.csv")
      )
    end
  end

  def base_input
    {
      "schemaVersion" => "1.0",
      "accounts" => [{ "accountId" => "acc-1" }],
      "markets" => [{ "marketId" => "ETH-USD" }],
      "feeModel" => { "enabled" => true },
      "trades" => [
        {
          "tradeId" => "t-1",
          "accountId" => "acc-1",
          "marketId" => "ETH-USD",
          "timestamp" => 1,
          "seq" => 1,
          "side" => "BUY",
          "quantityBase" => "2",
          "priceQuotePerBase" => "100",
          "fee" => { "amountQuote" => "1" }
        }
      ],
      "priceSnapshot" => {
        "valuationTimestamp" => "2026-02-25T03:00:00Z",
        "prices" => [{ "marketId" => "ETH-USD", "priceQuotePerBase" => "150" }],
        "fx" => { "quoteUsd" => "1" }
      }
    }
  end

  it "reconciles CSV artifacts against result.json" do
    run_with(input: base_input) do |paths|
      validator = FCS::Reporting::CsvArtifactReconciler.new
      expect do
        validator.validate!(
          json_path: paths.fetch(:json_path),
          positions_path: paths.fetch(:positions_path),
          pnl_path: paths.fetch(:pnl_path)
        )
      end.not_to raise_error
    end
  end

  it "raises diagnostic error when CSV mismatches canonical payload" do
    run_with(input: base_input) do |paths|
      rows = CSV.read(paths.fetch(:positions_path), headers: true)
      rows[0]["quantity"] = "999.0"

      CSV.open(paths.fetch(:positions_path), "w", write_headers: true, headers: rows.headers) do |csv|
        rows.each { |row| csv << row }
      end

      validator = FCS::Reporting::CsvArtifactReconciler.new
      expect do
        validator.validate!(
          json_path: paths.fetch(:json_path),
          positions_path: paths.fetch(:positions_path),
          pnl_path: paths.fetch(:pnl_path)
        )
      end.to raise_error(FCS::Error) { |error|
        expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(error.details).to include("impact", "next_action", "mismatch")
        expect(error.details.fetch("mismatch")).to eq("csv_row_mismatch")
      }
    end
  end

  it "fails when CSV contains duplicate account-market rows" do
    run_with(input: base_input) do |paths|
      rows = CSV.read(paths.fetch(:positions_path), headers: true)
      rows << rows[0]

      CSV.open(paths.fetch(:positions_path), "w", write_headers: true, headers: rows.headers) do |csv|
        rows.each { |row| csv << row }
      end

      validator = FCS::Reporting::CsvArtifactReconciler.new
      expect do
        validator.validate!(
          json_path: paths.fetch(:json_path),
          positions_path: paths.fetch(:positions_path),
          pnl_path: paths.fetch(:pnl_path)
        )
      end.to raise_error(FCS::Error) { |error|
        expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(error.details.fetch("mismatch")).to eq("csv_row_duplicate")
      }
    end
  end

  it "fails when CSV has partial USD totals across rows" do
    input = base_input
    input["markets"] = [{ "marketId" => "ETH-USD" }, { "marketId" => "BTC-USD" }]
    input["priceSnapshot"]["prices"] = [
      { "marketId" => "ETH-USD", "priceQuotePerBase" => "150" },
      { "marketId" => "BTC-USD", "priceQuotePerBase" => "60" }
    ]

    run_with(input: input) do |paths|
      json_payload = JSON.parse(File.read(paths.fetch(:json_path)))
      json_payload["global"]["totalPnLUsd"] = nil
      json_payload["accounts"][0]["markets"].each do |market|
        next unless market["marketId"] == "BTC-USD"

        market["totalPnLUsd"] = nil
      end
      File.write(paths.fetch(:json_path), JSON.pretty_generate(json_payload))

      rows = CSV.read(paths.fetch(:pnl_path), headers: true)
      rows.each do |row|
        row["total_pnl_usd"] = "" if row["market_id"] == "BTC-USD"
      end

      CSV.open(paths.fetch(:pnl_path), "w", write_headers: true, headers: rows.headers) do |csv|
        rows.each { |row| csv << row }
      end

      validator = FCS::Reporting::CsvArtifactReconciler.new
      expect do
        validator.validate!(
          json_path: paths.fetch(:json_path),
          positions_path: paths.fetch(:positions_path),
          pnl_path: paths.fetch(:pnl_path)
        )
      end.to raise_error(FCS::Error) { |error|
        expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(error.details.fetch("mismatch")).to eq("csv_global_total_usd_partial")
      }
    end
  end

  it "produces deterministic CSV artifacts for identical runs" do
    Dir.mktmpdir do |dir|
      input_path = File.join(dir, "input.json")
      File.write(input_path, JSON.pretty_generate(base_input))

      runner = FCS::Application::Runner.new
      out_a = File.join(dir, "out_a")
      out_b = File.join(dir, "out_b")

      runner.run!(input_path: input_path, output_dir: out_a, fee_enabled: true)
      runner.run!(input_path: input_path, output_dir: out_b, fee_enabled: true)

      expect(File.read(File.join(out_a, "positions.csv"))).to eq(File.read(File.join(out_b, "positions.csv")))
      expect(File.read(File.join(out_a, "pnl.csv"))).to eq(File.read(File.join(out_b, "pnl.csv")))
    end
  end
end
