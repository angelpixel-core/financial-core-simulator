# frozen_string_literal: true

require_relative "../../lib/fcs"
require "tmpdir"
require "csv"
require "json"

RSpec.describe FCS::Reporting::CsvArtifactReconciler do
  def write_csv(path, headers, rows)
    CSV.open(path, "w", write_headers: true, headers: headers) do |csv|
      rows.each { |row| csv << row }
    end
  end

  it "validates csv artifacts against result json" do
    Dir.mktmpdir do |dir|
      json_path = File.join(dir, "result.json")
      positions_path = File.join(dir, "positions.csv")
      pnl_path = File.join(dir, "pnl.csv")

      payload = {
        "accounts" => [
          {
            "accountId" => "acc-1",
            "markets" => [
              {
                "marketId" => "ETH-USD",
                "quantity" => "1",
                "avgCost" => "100",
                "realizedPnLQuote" => "1",
                "feesQuote" => "0.5",
                "realizedNetPnLQuote" => "0.5",
                "unrealizedPnLQuote" => "2",
                "totalPnLQuote" => "2.5",
                "totalPnLUsd" => "2.5"
              }
            ]
          }
        ],
        "global" => {
          "realizedPnLQuote" => "1",
          "feesQuote" => "0.5",
          "realizedNetPnLQuote" => "0.5",
          "unrealizedPnLQuote" => "2",
          "totalPnLQuote" => "2.5",
          "totalPnLUsd" => "2.5"
        }
      }

      File.write(json_path, JSON.pretty_generate(payload))

      write_csv(
        positions_path,
        FCS::Reporting::CsvPositions::HEADER,
        [%w[acc-1 ETH-USD 1 100]]
      )

      write_csv(
        pnl_path,
        FCS::Reporting::CsvPnL::HEADER,
        [["acc-1", "ETH-USD", "1", "0.5", "0.5", "2", "2.5", "2.5"]]
      )

      expect do
        described_class.new.validate!(json_path: json_path, positions_path: positions_path, pnl_path: pnl_path)
      end.not_to raise_error
    end
  end

  it "raises on csv header mismatch" do
    Dir.mktmpdir do |dir|
      json_path = File.join(dir, "result.json")
      positions_path = File.join(dir, "positions.csv")
      pnl_path = File.join(dir, "pnl.csv")

      File.write(json_path, JSON.pretty_generate({"accounts" => [], "global" => {}}))

      write_csv(positions_path, ["bad"], [])
      write_csv(pnl_path, FCS::Reporting::CsvPnL::HEADER, [])

      expect do
        described_class.new.validate!(json_path: json_path, positions_path: positions_path, pnl_path: pnl_path)
      end.to raise_error(FCS::Error) { |error| expect(error.details).to include("mismatch" => "csv_header_mismatch") }
    end
  end
end
