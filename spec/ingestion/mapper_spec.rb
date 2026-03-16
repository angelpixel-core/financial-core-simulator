# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe "Ingestion mappers" do
  it "validates agente intent event types" do
    mapper = FCS::Ingestion::AgenteIntentMapper.new

    event = {
      "source" => "agente.core",
      "eventType" => "BAD",
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

    expect do
      mapper.map!(event)
    end.to raise_error(FCS::Error) { |error| expect(error.details).to include(field: "sourceEvent.eventType") }
  end

  it "normalizes venue execution payload with optional fields" do
    mapper = FCS::Ingestion::VenueExecutionMapper.new

    event = {
      "source" => "venue.binance",
      "eventType" => "ORDER_FILLED",
      "eventVersion" => "1",
      "correlationId" => "corr-1",
      "occurredAt" => "2026-02-25T03:00:00Z",
      "payload" => {
        "externalOrderId" => "ex-1",
        "marketId" => "ETH-USD",
        "status" => "FILLED",
        "filledQuantityBase" => "1",
        "avgFillPriceQuotePerBase" => "100"
      }
    }

    normalized = mapper.map!(event)

    expect(normalized.fetch("payload")).to include(
      "filledQuantityBase" => "1",
      "avgFillPriceQuotePerBase" => "100"
    )
  end

  it "validates faucet issuance event types" do
    mapper = FCS::Ingestion::FaucetIssuanceMapper.new

    event = {
      "source" => "faucet.core",
      "eventType" => "BAD",
      "eventVersion" => "1",
      "correlationId" => "corr-1",
      "occurredAt" => "2026-02-25T03:00:00Z",
      "payload" => {
        "walletAddress" => "0xabc",
        "tokenSymbol" => "USDC",
        "amount" => "10"
      }
    }

    expect do
      mapper.map!(event)
    end.to raise_error(FCS::Error) { |error| expect(error.details).to include(field: "sourceEvent.eventType") }
  end
end
