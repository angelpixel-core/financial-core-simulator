require "stringio"
require "tmpdir"
require "fileutils"

require_relative "../../lib/fcs"

RSpec.describe FCS::Reporting::CliSummary do
  let(:payload) do
    {
      "engineVersion" => "1.2.3",
      "schemaVersion" => "1.0",
      "inputHash" => "hash-123",
      "runId" => "run-abc",
      "valuationTimestamp" => "2026-03-01T00:00:00Z",
      "global" => {
        "realizedPnLQuote" => "1.0",
        "feesQuote" => "0.1",
        "realizedNetPnLQuote" => "0.9",
        "unrealizedPnLQuote" => "0.2",
        "totalPnLQuote" => "1.1",
        "totalPnLUsd" => "1.1"
      },
      "accounts" => []
    }
  end

  it "prints deterministic summary with stable order and content" do
    Dir.mktmpdir do |tmp|
      output_dir = File.join(tmp, "out")
      FileUtils.mkdir_p(output_dir)

      result_json = File.join(output_dir, "result.json")
      positions_csv = File.join(output_dir, "positions.csv")
      pnl_csv = File.join(output_dir, "pnl.csv")

      File.write(result_json, "{}")
      File.write(positions_csv, "")
      File.write(pnl_csv, "")

      io = StringIO.new
      summary = described_class.new(io: io)
      summary.print(
        payload,
        artifacts: {
          json_path: result_json,
          positions_csv_path: positions_csv,
          pnl_csv_path: pnl_csv
        },
        status: "success"
      )

      expected_lines = [
        "=== fcs_summary ===",
        "status: success",
        "run_id: run-abc",
        "input_hash: hash-123",
        "schema_version: 1.0",
        "engine_version: 1.2.3",
        "valuation_timestamp: 2026-03-01T00:00:00Z",
        "metrics:",
        "  realized_pnl_quote: 1.0",
        "  fees_quote: 0.1",
        "  realized_net_pnl_quote: 0.9",
        "  unrealized_pnl_quote: 0.2",
        "  total_pnl_quote: 1.1",
        "  total_pnl_usd: 1.1",
        "artifacts:",
        "  result_json: #{result_json}",
        "  positions_csv: #{positions_csv}",
        "  pnl_csv: #{pnl_csv}"
      ]

      expect(io.string).to eq(expected_lines.join("\n") + "\n")
    end
  end

  it "prints the same summary for identical inputs and paths" do
    Dir.mktmpdir do |tmp|
      output_dir = File.join(tmp, "out")
      FileUtils.mkdir_p(output_dir)

      result_json = File.join(output_dir, "result.json")
      positions_csv = File.join(output_dir, "positions.csv")
      pnl_csv = File.join(output_dir, "pnl.csv")

      File.write(result_json, "{}")
      File.write(positions_csv, "")
      File.write(pnl_csv, "")

      io_a = StringIO.new
      io_b = StringIO.new

      summary = described_class.new(io: io_a)
      summary.print(
        payload,
        artifacts: {
          json_path: result_json,
          positions_csv_path: positions_csv,
          pnl_csv_path: pnl_csv
        },
        status: "success"
      )

      summary_b = described_class.new(io: io_b)
      summary_b.print(
        payload,
        artifacts: {
          json_path: result_json,
          positions_csv_path: positions_csv,
          pnl_csv_path: pnl_csv
        },
        status: "success"
      )

      expect(io_a.string).to eq(io_b.string)
    end
  end

  it "raises a deterministic error when required artifacts are missing" do
    Dir.mktmpdir do |tmp|
      output_dir = File.join(tmp, "out")
      FileUtils.mkdir_p(output_dir)

      result_json = File.join(output_dir, "result.json")
      positions_csv = File.join(output_dir, "positions.csv")
      pnl_csv = File.join(output_dir, "pnl.csv")

      File.write(result_json, "{}")
      File.write(positions_csv, "")

      io = StringIO.new
      summary = described_class.new(io: io)

      expect do
        summary.print(
          payload,
          artifacts: {
            json_path: result_json,
            positions_csv_path: positions_csv,
            pnl_csv_path: pnl_csv
          },
          status: "success"
        )
      end.to raise_error(FCS::Error) { |error|
        expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(error.details.fetch("missing_artifacts")).to include("pnl_csv" => pnl_csv)
      }
    end
  end

  it "fails when required artifact paths are nil" do
    io = StringIO.new
    summary = described_class.new(io: io)

    expect do
      summary.print(
        payload,
        artifacts: {
          json_path: nil,
          positions_csv_path: nil,
          pnl_csv_path: nil
        },
        status: "success"
      )
    end.to raise_error(FCS::Error) { |error|
      expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
      expect(error.details.fetch("missing_artifacts")).to include(
        "result_json" => nil,
        "positions_csv" => nil,
        "pnl_csv" => nil
      )
    }
  end
end
