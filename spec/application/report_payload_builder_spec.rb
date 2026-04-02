# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Application::ReportPayloadBuilder do
  it "builds the canonical report payload shape" do
    payload = described_class.build(
      engine_version: "0.1.0",
      schema_version: "1.0",
      input_hash: "abc123",
      run_id: "run-1",
      valuation_timestamp: "2026-02-25T03:00:00Z",
      accounts: [{"accountId" => "acc-1"}],
      global: {"totalPnLQuote" => "0.0"}
    )

    expect(payload).to eq(
      "engineVersion" => "0.1.0",
      "schemaVersion" => "1.0",
      "inputHash" => "abc123",
      "runId" => "run-1",
      "valuationTimestamp" => "2026-02-25T03:00:00Z",
      "accounts" => [{"accountId" => "acc-1"}],
      "global" => {"totalPnLQuote" => "0.0"}
    )
  end

  it "adds replay metadata only when provided" do
    payload = described_class.build(
      engine_version: "0.1.0",
      schema_version: "1.0",
      input_hash: "abc123",
      run_id: "run-1",
      valuation_timestamp: "2026-02-25T03:00:00Z",
      accounts: [{"accountId" => "acc-1"}],
      global: {"totalPnLQuote" => "0.0"},
      replay: {
        "mode" => "timeline",
        "checkpointTimelineSeq" => 42
      }
    )

    expect(payload).to include(
      "engineVersion" => "0.1.0",
      "schemaVersion" => "1.0",
      "replay" => {
        "mode" => "timeline",
        "checkpointTimelineSeq" => 42
      }
    )
  end

  it "adds timeline metadata when provided" do
    payload = described_class.build(
      engine_version: "0.1.0",
      schema_version: "1.0",
      input_hash: "abc123",
      run_id: "run-1",
      valuation_timestamp: "2026-02-25T03:00:00Z",
      accounts: [{"accountId" => "acc-1"}],
      global: {"totalPnLQuote" => "0.0"},
      timeline: {
        "schema_version" => "1.0",
        "points" => [{"timestamp" => "2026-03-29T12:00:00Z"}]
      }
    )

    expect(payload).to include(
      "timeline" => {
        "schema_version" => "1.0",
        "points" => [{"timestamp" => "2026-03-29T12:00:00Z"}]
      }
    )
  end
end
