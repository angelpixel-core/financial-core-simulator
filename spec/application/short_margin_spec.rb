# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe "Long-only integration guardrails" do
  it "rejects short opening attempts even when risk model and collateral are provided" do
    input = {
      "schemaVersion" => "1.0",
      "accounts" => [{ "accountId" => "acc-1", "collateralQuote" => "100" }],
      "markets" => [{ "marketId" => "ETH-USD" }],
      "feeModel" => { "enabled" => false },
      "riskModel" => { "maxLeverage" => "2" },
      "trades" => [
        {
          "tradeId" => "s1",
          "accountId" => "acc-1",
          "marketId" => "ETH-USD",
          "timestamp" => 1,
          "seq" => 1,
          "side" => "SELL",
          "quantityBase" => "1",
          "priceQuotePerBase" => "100"
        }
      ],
      "priceSnapshot" => {
        "valuationTimestamp" => "2026-02-25T03:00:00Z",
        "prices" => [{ "marketId" => "ETH-USD", "priceQuotePerBase" => "80" }]
      }
    }

    expect do
      FCS::Application::Simulate.new.call(input)
    end.to raise_error(FCS::Error) { |error| expect(error.code).to eq(FCS::Errors::ERR_POSITION_NEGATIVE) }
  end

  it "keeps risk events empty on regular long-only flow" do
    input = {
      "schemaVersion" => "1.0",
      "accounts" => [{ "accountId" => "acc-1", "collateralQuote" => "100" }],
      "markets" => [{ "marketId" => "ETH-USD" }],
      "feeModel" => { "enabled" => false },
      "riskModel" => {
        "maxLeverage" => "2",
        "maintenanceMarginRatio" => "0.25",
        "liquidation" => { "enabled" => true, "closeFactor" => "0.5" }
      },
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
        }
      ],
      "priceSnapshot" => {
        "valuationTimestamp" => "2026-02-25T03:00:00Z",
        "prices" => [{ "marketId" => "ETH-USD", "priceQuotePerBase" => "90" }]
      }
    }

    result = FCS::Application::Simulate.new.call(input)
    account = result["accounts"][0]

    expect(account["risk"]["status"]).to eq(FCS::Engine::RiskEngine::STATUS_HEALTHY)
    expect(account["riskEvents"]).to eq([])
  end
end
