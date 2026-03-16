# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe "FIFO option" do
  it "uses FIFO accounting when accountingModel.method is FIFO" do
    input = {
      "schemaVersion" => "1.0",
      "accounts" => [{ "accountId" => "acc-1" }],
      "markets" => [{ "marketId" => "ETH-USD" }],
      "feeModel" => { "enabled" => false },
      "accountingModel" => { "method" => "FIFO" },
      "trades" => [
        {
          "tradeId" => "b1",
          "accountId" => "acc-1",
          "marketId" => "ETH-USD",
          "timestamp" => 1,
          "seq" => 1,
          "side" => "BUY",
          "quantityBase" => "1",
          "priceQuotePerBase" => "100"
        },
        {
          "tradeId" => "b2",
          "accountId" => "acc-1",
          "marketId" => "ETH-USD",
          "timestamp" => 2,
          "seq" => 2,
          "side" => "BUY",
          "quantityBase" => "1",
          "priceQuotePerBase" => "120"
        },
        {
          "tradeId" => "s1",
          "accountId" => "acc-1",
          "marketId" => "ETH-USD",
          "timestamp" => 3,
          "seq" => 3,
          "side" => "SELL",
          "quantityBase" => "1",
          "priceQuotePerBase" => "130"
        }
      ],
      "priceSnapshot" => {
        "valuationTimestamp" => "2026-02-25T03:00:00Z",
        "prices" => [{ "marketId" => "ETH-USD", "priceQuotePerBase" => "130" }]
      }
    }

    result = FCS::Application::Simulate.new.call(input)
    market = result["accounts"][0]["markets"][0]

    expect(market["realizedPnLQuote"]).to eq("30.0")
    expect(market["avgCost"]).to eq("120.0")
  end
end
