# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe "USD badge disabled" do
  it "keeps totalPnLUsd null when fx is missing" do
    input = {
      "schemaVersion" => "1.0",
      "accounts" => [{"accountId" => "acc-1"}],
      "markets" => [{"marketId" => "ETH-USD"}],
      "feeModel" => {"enabled" => false},
      "trades" => [],
      "priceSnapshot" => {
        "valuationTimestamp" => "2026-02-25T03:00:00Z",
        "prices" => [{"marketId" => "ETH-USD", "priceQuotePerBase" => "150"}]
      }
    }

    result = FCS::Application::Simulate.new.call(input)
    expect(result["accounts"][0]["totals"]["totalPnLUsd"]).to be_nil
    expect(result["global"]["totalPnLUsd"]).to be_nil
  end

  it "keeps totalPnLUsd null when usdModel.enabled is false" do
    input = {
      "schemaVersion" => "1.0",
      "usdModel" => {"enabled" => false},
      "accounts" => [{"accountId" => "acc-1"}],
      "markets" => [{"marketId" => "ETH-USD"}],
      "feeModel" => {"enabled" => false},
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
        "prices" => [{"marketId" => "ETH-USD", "priceQuotePerBase" => "150"}],
        "fx" => {"quoteUsd" => "2"}
      }
    }

    result = FCS::Application::Simulate.new.call(input)
    expect(result["accounts"][0]["totals"]["totalPnLUsd"]).to be_nil
    expect(result["global"]["totalPnLUsd"]).to be_nil
  end
end
