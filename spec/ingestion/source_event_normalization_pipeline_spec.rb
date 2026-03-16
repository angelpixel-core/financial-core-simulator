# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Ingestion::SourceEventNormalizationPipeline do
  let(:pipeline) { described_class.new }

  it "normalizes agente source events" do
    event = {
      "source" => "agente.core",
      "eventType" => "ORDER_INTENT_CREATED",
      "eventVersion" => "1",
      "correlationId" => "corr-1",
      "occurredAt" => "2026-02-25T03:00:00Z",
      "payload" => {
        "agentId" => "agent-1",
        "marketId" => "ETH-USD",
        "side" => "BUY",
        "quantityBase" => "1",
        "priceQuotePerBase" => "100"
      }
    }

    normalized = pipeline.normalize!(event)

    expect(normalized.fetch("eventType")).to eq("AGENTE_INTENT_NORMALIZED")
    expect(normalized.fetch("payload")).to include("agentId" => "agent-1")
  end

  it "normalizes venue source events" do
    event = {
      "source" => "venue.binance",
      "eventType" => "ORDER_ACKNOWLEDGED",
      "eventVersion" => "1",
      "correlationId" => "corr-1",
      "occurredAt" => "2026-02-25T03:00:00Z",
      "payload" => {
        "externalOrderId" => "ex-1",
        "marketId" => "ETH-USD",
        "status" => "ACK"
      }
    }

    normalized = pipeline.normalize!(event)

    expect(normalized.fetch("eventType")).to eq("VENUE_EXECUTION_NORMALIZED")
    expect(normalized.fetch("payload")).to include("externalOrderId" => "ex-1")
  end

  it "normalizes faucet source events" do
    event = {
      "source" => "faucet.core",
      "eventType" => "TOKEN_ISSUED",
      "eventVersion" => "1",
      "correlationId" => "corr-1",
      "occurredAt" => "2026-02-25T03:00:00Z",
      "payload" => {
        "walletAddress" => "0xabc",
        "tokenSymbol" => "USDC",
        "amount" => "10"
      }
    }

    normalized = pipeline.normalize!(event)

    expect(normalized.fetch("eventType")).to eq("FAUCET_ISSUANCE_NORMALIZED")
    expect(normalized.fetch("payload")).to include("walletAddress" => "0xabc")
  end

  it "rejects unsupported sources" do
    event = {
      "source" => "unknown",
      "eventType" => "ORDER_ACKNOWLEDGED",
      "eventVersion" => "1",
      "correlationId" => "corr-1",
      "occurredAt" => "2026-02-25T03:00:00Z",
      "payload" => {}
    }

    expect do
      pipeline.normalize!(event)
    end.to raise_error(FCS::Error) { |error| expect(error.details).to include(field: "sourceEvent.source") }
  end

  it "rejects invalid batch shapes" do
    expect do
      pipeline.normalize_batch!("nope")
    end.to raise_error(FCS::Error) { |error| expect(error.details).to include(field: "sourceEvents") }
  end
end
