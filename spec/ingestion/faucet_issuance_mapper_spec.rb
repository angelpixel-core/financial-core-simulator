# frozen_string_literal: true

require_relative "../../lib/fcs"
require "json"

RSpec.describe FCS::Ingestion::FaucetIssuanceMapper do
  subject(:mapper) { described_class.new }

  def fixture(name)
    path = File.join(__dir__, "..", "fixtures", "source_events", name)
    JSON.parse(File.read(path))
  end

  it "maps faucet TOKEN_ISSUED into canonical execution event" do
    source_event = fixture("valid_faucet_issuance.json")

    normalized = mapper.map!(source_event)

    expect(normalized).to include(
      "source" => "faucet.erc20.ang",
      "eventType" => "FAUCET_ISSUANCE_NORMALIZED",
      "correlationId" => "corr-faucet-001",
      "occurredAt" => "2026-03-04T10:00:02Z"
    )

    expect(normalized.fetch("payload")).to include(
      "walletAddress" => "0xabc123abc123abc123abc123abc123abc123abcd",
      "tokenSymbol" => "ANG",
      "amount" => "1000"
    )

    expect(normalized.fetch("trace")).to include(
      "sourceEventType" => "TOKEN_ISSUED",
      "sourceEventVersion" => "1.0",
      "sourceCorrelationId" => "corr-faucet-001"
    )
  end

  it "rejects non-faucet event type for faucet mapper" do
    source_event = fixture("valid_faucet_issuance.json")
    source_event["eventType"] = "ORDER_FILLED"

    expect { mapper.map!(source_event) }
      .to raise_error(FCS::Error) { |error|
        expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(error.details).to include(field: "sourceEvent.eventType")
      }
  end
end
