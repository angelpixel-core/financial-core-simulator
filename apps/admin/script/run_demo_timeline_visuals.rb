input = {
  "schemaVersion" => "1.0",
  "accounts" => [
    {"accountId" => "acc-1", "collateralQuote" => "15000"},
    {"accountId" => "acc-2", "collateralQuote" => "15000"},
    {"accountId" => "acc-3", "collateralQuote" => "15000"}
  ],
  "markets" => [
    {"marketId" => "BTC-USD"},
    {"marketId" => "ETH-USD"}
  ],
  "feeModel" => {"enabled" => true},
  "accountingModel" => {
    "allowShort" => true,
    "shortMode" => "MARGIN"
  },
  "riskModel" => {
    "maxLeverage" => "3",
    "maintenanceMarginRatio" => "0.25",
    "liquidation" => {
      "enabled" => true,
      "closeFactor" => "0.5"
    }
  },
  "trades" => [],
  "timeline" => {
    "events" => [
      {
        "eventType" => "PRICE_UPDATED",
        "timelineSeq" => 1,
        "timestamp" => "2026-03-03T12:00:01Z",
        "source" => "feed.demo",
        "externalId" => "px-btc-1",
        "marketId" => "BTC-USD",
        "priceQuotePerBase" => "60000"
      },
      {
        "eventType" => "PRICE_UPDATED",
        "timelineSeq" => 2,
        "timestamp" => "2026-03-03T12:00:01Z",
        "source" => "feed.demo",
        "externalId" => "px-eth-1",
        "marketId" => "ETH-USD",
        "priceQuotePerBase" => "3000"
      },
      {
        "eventType" => "TRADE_APPLIED",
        "timelineSeq" => 3,
        "timestamp" => "2026-03-03T12:00:02Z",
        "source" => "sim.demo",
        "externalId" => "tr-1",
        "trade" => {
          "tradeId" => "t-1",
          "accountId" => "acc-1",
          "marketId" => "BTC-USD",
          "timestamp" => 1,
          "seq" => 1,
          "side" => "BUY",
          "quantityBase" => "0.5",
          "priceQuotePerBase" => "59000",
          "fee" => {"amountQuote" => "5"}
        }
      },
      {
        "eventType" => "TRADE_APPLIED",
        "timelineSeq" => 4,
        "timestamp" => "2026-03-03T12:00:03Z",
        "source" => "sim.demo",
        "externalId" => "tr-2",
        "trade" => {
          "tradeId" => "t-2",
          "accountId" => "acc-2",
          "marketId" => "ETH-USD",
          "timestamp" => 2,
          "seq" => 1,
          "side" => "BUY",
          "quantityBase" => "4",
          "priceQuotePerBase" => "2800",
          "fee" => {"amountQuote" => "4"}
        }
      },
      {
        "eventType" => "TRADE_APPLIED",
        "timelineSeq" => 5,
        "timestamp" => "2026-03-03T12:00:04Z",
        "source" => "sim.demo",
        "externalId" => "tr-3",
        "trade" => {
          "tradeId" => "t-3",
          "accountId" => "acc-3",
          "marketId" => "ETH-USD",
          "timestamp" => 3,
          "seq" => 1,
          "side" => "SELL",
          "quantityBase" => "3",
          "priceQuotePerBase" => "3000",
          "fee" => {"amountQuote" => "3"}
        }
      },
      {
        "eventType" => "PRICE_UPDATED",
        "timelineSeq" => 6,
        "timestamp" => "2026-03-03T12:00:05Z",
        "source" => "feed.demo",
        "externalId" => "px-btc-2",
        "marketId" => "BTC-USD",
        "priceQuotePerBase" => "55000"
      },
      {
        "eventType" => "PRICE_UPDATED",
        "timelineSeq" => 7,
        "timestamp" => "2026-03-03T12:00:05Z",
        "source" => "feed.demo",
        "externalId" => "px-eth-2",
        "marketId" => "ETH-USD",
        "priceQuotePerBase" => "2200"
      }
    ]
  },
  "priceSnapshot" => {
    "valuationTimestamp" => "2026-03-03T12:00:00Z",
    "prices" => [
      {"marketId" => "BTC-USD", "priceQuotePerBase" => "60000"},
      {"marketId" => "ETH-USD", "priceQuotePerBase" => "3000"}
    ],
    "fx" => {"quoteUsd" => "1"}
  }
}

run = Run.create!(input_json: input)

previous_timeline = ENV["FCS_TIMELINE_ENABLED"]
previous_checkpoint_every = ENV["FCS_CHECKPOINT_EVERY"]

begin
  ENV["FCS_TIMELINE_ENABLED"] = "1"
  ENV["FCS_CHECKPOINT_EVERY"] = "2"

  Runs::Execute.new.call(run)

  puts "OK run=#{run.id} status=#{run.status} input_hash=#{run.input_hash}"
  puts "result.json: #{run.result_json_path}"
ensure
  ENV["FCS_TIMELINE_ENABLED"] = previous_timeline
  ENV["FCS_CHECKPOINT_EVERY"] = previous_checkpoint_every
end
