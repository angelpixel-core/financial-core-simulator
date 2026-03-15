# frozen_string_literal: true

require_relative "../../lib/fcs"
require "stringio"

RSpec.describe FCS::Reporting::CliSummary do
  it "prints into the injected IO without touching global stdout" do
    payload = {
      "engineVersion" => "0.1.0",
      "schemaVersion" => "1.0",
      "runId" => "run-1",
      "valuationTimestamp" => "2026-02-25T03:00:00Z",
      "inputHash" => "abc",
      "global" => {
        "realizedPnLQuote" => "0.0",
        "feesQuote" => "0.0",
        "realizedNetPnLQuote" => "0.0",
        "unrealizedPnLQuote" => "0.0",
        "totalPnLQuote" => "0.0",
        "totalPnLUsd" => nil
      },
      "accounts" => [
        {
          "accountId" => "acc-1",
          "totals" => {
            "totalPnLQuote" => "0.0",
            "totalPnLUsd" => nil
          }
        }
      ]
    }

    out = StringIO.new
    described_class.new(io: out).print(payload, validate_artifacts: false)

    expect(out.string).to include("fcs_summary")
    expect(out.string).to include("metrics:")
    expect(out.string).to include("artifacts:")
  end
end
