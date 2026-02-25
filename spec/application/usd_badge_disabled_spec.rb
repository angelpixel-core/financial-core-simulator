# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe "USD badge disabled" do
  it "keeps totalPnLUsd null when fx is missing" do
    input = {
      "schemaVersion" => "1.0",
      "accounts" => [{ "accountId" => "acc-1" }],
      "markets" => [{ "marketId" => "ETH-USD" }],
      "feeModel" => { "enabled" => false },
      "trades" => [],
      "priceSnapshot" => {
        "valuationTimestamp" => "2026-02-25T03:00:00Z",
        "prices" => [{ "marketId" => "ETH-USD", "priceQuotePerBase" => "150" }]
      }
    }

    result = FCS::Application::Simulate.new.call(input)
    expect(result["accounts"][0]["totals"]["totalPnLUsd"]).to be_nil
    expect(result["global"]["totalPnLUsd"]).to be_nil
  end
end
