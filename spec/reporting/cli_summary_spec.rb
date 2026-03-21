# frozen_string_literal: true

require_relative "../../lib/fcs"
require "stringio"
require "tmpdir"

RSpec.describe FCS::Reporting::CliSummary do
  let(:payload) do
    {
      "runId" => "run-1",
      "inputHash" => "hash",
      "schemaVersion" => "1.0",
      "engineVersion" => "0.1.0",
      "valuationTimestamp" => "2026-02-25T03:00:00Z",
      "global" => {
        "realizedPnLQuote" => "1",
        "feesQuote" => "0.5",
        "realizedNetPnLQuote" => "0.5",
        "unrealizedPnLQuote" => "2",
        "totalPnLQuote" => "2.5",
        "totalPnLUsd" => nil
      }
    }
  end

  it "prints summary with artifacts" do
    io = StringIO.new
    summary = described_class.new(io: io)

    Dir.mktmpdir do |dir|
      json_path = File.join(dir, "result.json")
      positions_path = File.join(dir, "positions.csv")
      pnl_path = File.join(dir, "pnl.csv")

      File.write(json_path, "{}")
      File.write(positions_path, "")
      File.write(pnl_path, "")

      summary.print(payload, artifacts: {
        json_path: json_path,
        positions_csv_path: positions_path,
        pnl_csv_path: pnl_path
      })
    end

    output = io.string
    expect(output).to include("=== fcs_summary ===")
    expect(output).to include("run_id: run-1")
    expect(output).to include("total_pnl_usd: n/a")
    expect(output).to include("positions_csv:")
  end

  it "raises when artifacts are missing" do
    io = StringIO.new
    summary = described_class.new(io: io)

    expect do
      summary.print(payload, artifacts: {json_path: "missing.json"})
    end.to raise_error(FCS::Error) { |error| expect(error.code).to eq(FCS::Errors::ERR_VALIDATION) }
  end
end
