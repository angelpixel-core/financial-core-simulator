# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe "Timeline processing integration" do
  def base_input
    {
      "schemaVersion" => "1.0",
      "accounts" => [{"accountId" => "acc-1"}],
      "markets" => [{"marketId" => "ETH-USD"}],
      "feeModel" => {"enabled" => false},
      "trades" => [],
      "priceSnapshot" => {
        "valuationTimestamp" => "2026-03-03T12:00:00Z",
        "prices" => [{"marketId" => "ETH-USD", "priceQuotePerBase" => "100"}]
      }
    }
  end

  it "applies interleaved timeline flow price->trade to positions" do
    input = base_input
    input["timeline"] = {
      "events" => [
        {
          "eventType" => "PRICE_UPDATED",
          "timelineSeq" => 1,
          "timestamp" => "2026-03-03T12:00:01Z",
          "source" => "feed.binance",
          "externalId" => "px-1",
          "marketId" => "ETH-USD",
          "priceQuotePerBase" => "120"
        },
        {
          "eventType" => "TRADE_APPLIED",
          "timelineSeq" => 2,
          "timestamp" => "2026-03-03T12:00:02Z",
          "source" => "sim.core",
          "externalId" => "tr-1",
          "trade" => {
            "tradeId" => "t-1",
            "accountId" => "acc-1",
            "marketId" => "ETH-USD",
            "seq" => 1,
            "side" => "BUY",
            "quantityBase" => "1",
            "priceQuotePerBase" => "100"
          }
        }
      ]
    }

    result = FCS::Application::Simulate.new.call(input)
    market = result.fetch("accounts").first.fetch("markets").first

    expect(market.fetch("quantity")).to eq("1.0")
  end

  it "uses latest timeline price update before trade valuation" do
    input = base_input
    input["timeline"] = {
      "events" => [
        {
          "eventType" => "PRICE_UPDATED",
          "timelineSeq" => 1,
          "timestamp" => "2026-03-03T12:00:01Z",
          "source" => "feed.binance",
          "externalId" => "px-1",
          "marketId" => "ETH-USD",
          "priceQuotePerBase" => "105"
        },
        {
          "eventType" => "PRICE_UPDATED",
          "timelineSeq" => 2,
          "timestamp" => "2026-03-03T12:00:02Z",
          "source" => "feed.binance",
          "externalId" => "px-2",
          "marketId" => "ETH-USD",
          "priceQuotePerBase" => "110"
        },
        {
          "eventType" => "TRADE_APPLIED",
          "timelineSeq" => 3,
          "timestamp" => "2026-03-03T12:00:03Z",
          "source" => "sim.core",
          "externalId" => "tr-1",
          "trade" => {
            "tradeId" => "t-1",
            "accountId" => "acc-1",
            "marketId" => "ETH-USD",
            "seq" => 1,
            "side" => "BUY",
            "quantityBase" => "1",
            "priceQuotePerBase" => "100"
          }
        }
      ]
    }

    result = FCS::Application::Simulate.new.call(input)
    market = result.fetch("accounts").first.fetch("markets").first

    expect(market.fetch("unrealizedPnLQuote")).to eq("10.0")
  end

  it "replays identical interleaved timeline with exact same result" do
    input = base_input
    input["timeline"] = {
      "events" => [
        {
          "eventType" => "PRICE_UPDATED",
          "timelineSeq" => 1,
          "timestamp" => "2026-03-03T12:00:01Z",
          "source" => "feed.binance",
          "externalId" => "px-1",
          "marketId" => "ETH-USD",
          "priceQuotePerBase" => "101"
        },
        {
          "eventType" => "TRADE_APPLIED",
          "timelineSeq" => 2,
          "timestamp" => "2026-03-03T12:00:02Z",
          "source" => "sim.core",
          "externalId" => "tr-1",
          "trade" => {
            "tradeId" => "t-1",
            "accountId" => "acc-1",
            "marketId" => "ETH-USD",
            "seq" => 1,
            "side" => "BUY",
            "quantityBase" => "1",
            "priceQuotePerBase" => "100"
          }
        },
        {
          "eventType" => "PRICE_UPDATED",
          "timelineSeq" => 3,
          "timestamp" => "2026-03-03T12:00:03Z",
          "source" => "feed.binance",
          "externalId" => "px-2",
          "marketId" => "ETH-USD",
          "priceQuotePerBase" => "103"
        }
      ]
    }

    first = FCS::Application::Simulate.new.call(input)
    second = FCS::Application::Simulate.new.call(input)

    expect(first).to eq(second)
    expect(first.fetch("accounts").first.fetch("markets").first.fetch("quantity")).to eq("1.0")
  end

  it "keeps final output equivalent between full replay and checkpoint-seeded replay" do
    full_input = base_input
    full_input["timeline"] = {
      "events" => [
        {
          "eventType" => "TRADE_APPLIED",
          "timelineSeq" => 1,
          "timestamp" => "2026-03-03T12:00:01Z",
          "source" => "sim.core",
          "externalId" => "tr-1",
          "trade" => {
            "tradeId" => "t-1",
            "accountId" => "acc-1",
            "marketId" => "ETH-USD",
            "seq" => 1,
            "side" => "BUY",
            "quantityBase" => "1",
            "priceQuotePerBase" => "100"
          }
        },
        {
          "eventType" => "PRICE_UPDATED",
          "timelineSeq" => 2,
          "timestamp" => "2026-03-03T12:00:02Z",
          "source" => "feed.binance",
          "externalId" => "px-1",
          "marketId" => "ETH-USD",
          "priceQuotePerBase" => "120"
        }
      ]
    }

    from_checkpoint_input = base_input
    from_checkpoint_input["checkpoint"] = {
      "timelineSeq" => 1,
      "state" => {
        "accounts" => [
          {
            "accountId" => "acc-1",
            "markets" => [
              {
                "marketId" => "ETH-USD",
                "quantity" => "1.0",
                "avgCost" => "100.0"
              }
            ]
          }
        ]
      },
      "metadata" => {
        "engineVersion" => FCS::VERSION,
        "schemaVersion" => "1.0",
        "inputHash" => "checkpoint-hash",
        "stateHash" => "state-hash"
      }
    }
    from_checkpoint_input["timeline"] = {
      "events" => [
        {
          "eventType" => "PRICE_UPDATED",
          "timelineSeq" => 2,
          "timestamp" => "2026-03-03T12:00:02Z",
          "source" => "feed.binance",
          "externalId" => "px-1",
          "marketId" => "ETH-USD",
          "priceQuotePerBase" => "120"
        }
      ]
    }

    full_replay = FCS::Application::Simulate.new.call(full_input)
    checkpoint_replay = FCS::Application::Simulate.new.call(from_checkpoint_input)

    expect(checkpoint_replay).to eq(full_replay)
  end

  it "falls back safely when checkpoint state is missing" do
    full_input = base_input
    full_input["timeline"] = {
      "events" => [
        {
          "eventType" => "TRADE_APPLIED",
          "timelineSeq" => 1,
          "timestamp" => "2026-03-03T12:00:01Z",
          "source" => "sim.core",
          "externalId" => "tr-1",
          "trade" => {
            "tradeId" => "t-1",
            "accountId" => "acc-1",
            "marketId" => "ETH-USD",
            "seq" => 1,
            "side" => "BUY",
            "quantityBase" => "1",
            "priceQuotePerBase" => "100"
          }
        },
        {
          "eventType" => "PRICE_UPDATED",
          "timelineSeq" => 2,
          "timestamp" => "2026-03-03T12:00:02Z",
          "source" => "feed.binance",
          "externalId" => "px-1",
          "marketId" => "ETH-USD",
          "priceQuotePerBase" => "120"
        }
      ]
    }

    missing_checkpoint_input = base_input
    missing_checkpoint_input["checkpoint"] = {
      "timelineSeq" => 1,
      "metadata" => {
        "engineVersion" => FCS::VERSION,
        "schemaVersion" => "1.0",
        "inputHash" => "checkpoint-hash",
        "stateHash" => "state-hash"
      }
    }
    missing_checkpoint_input["timeline"] = full_input.fetch("timeline")

    full_replay = FCS::Application::Simulate.new.call(full_input)
    replay_with_missing_checkpoint = FCS::Application::Simulate.new.call(missing_checkpoint_input)

    expect(replay_with_missing_checkpoint).to eq(full_replay)
  end
end
