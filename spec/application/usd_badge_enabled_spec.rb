# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe "USD badge enabled" do
  it "computes totalPnLUsd using quoteUsd fx rate" do
    input = {
      "schemaVersion" => "1.0",
      "accounts" => [{ "accountId" => "acc-1" }],
      "markets" => [{ "marketId" => "ETH-USD" }],
      "feeModel" => { "enabled" => false },
      "trades" => [
        {
          "tradeId" => "b1",
          "accountId" => "acc-1",
          "marketId" => "ETH-USD",
          "timestamp" => 1,
          "seq" => 1,
          "side" => "BUY",
          "quantityBase" => "2",
          "priceQuotePerBase" => "100"
        }
      ],
      "priceSnapshot" => {
        "valuationTimestamp" => "2026-02-25T03:00:00Z",
        "prices" => [{ "marketId" => "ETH-USD", "priceQuotePerBase" => "150" }],
        "fx" => { "quoteUsd" => "2" }
      }
    }

    result = FCS::Application::Simulate.new.call(input)
    # unrealized = (150-100)*2 = 100 quote
    # totalPnLUsd = 100 * 2 = 200
    expect(result["accounts"][0]["totals"]["totalPnLUsd"]).to eq("200.0")
    expect(result["global"]["totalPnLUsd"]).to eq("200.0")
  end

  it "fails deterministically when usdModel.enabled is true and fx.quoteUsd is missing" do
    input = {
      "schemaVersion" => "1.0",
      "usdModel" => { "enabled" => true },
      "accounts" => [{ "accountId" => "acc-1" }],
      "markets" => [{ "marketId" => "ETH-USD" }],
      "feeModel" => { "enabled" => false },
      "trades" => [],
      "priceSnapshot" => {
        "valuationTimestamp" => "2026-02-25T03:00:00Z",
        "prices" => [{ "marketId" => "ETH-USD", "priceQuotePerBase" => "150" }]
      }
    }

    expect { FCS::Application::Simulate.new.call(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_MISSING_SNAPSHOT)
        expect(e.details).to include(
          missingField: "priceSnapshot.fx.quoteUsd",
          what_happened: "USD conversion is enabled but quoteUsd FX rate is missing from snapshot.",
          impact: "Account and global USD totals cannot be calculated deterministically.",
          next_action: "Provide priceSnapshot.fx.quoteUsd as a positive decimal string, or disable usdModel.enabled."
        )
      }
  end
end
