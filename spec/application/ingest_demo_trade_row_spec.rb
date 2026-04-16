# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Application::IngestDemoTradeRow do
  it "normalizes spreadsheet row into trade contract payload" do
    row = {
      "trade_id" => "trade-1",
      "account_id" => "acc-1",
      "market_id" => "ETH-USD",
      "timestamp" => "1700000000",
      "seq" => "1",
      "side" => "BUY",
      "quantity_base" => "1.5",
      "price_quote_per_base" => "100.25"
    }

    trade = described_class.new.call(row: row, line: 2)

    expect(trade).to include(
      tradeId: "trade-1",
      accountId: "acc-1",
      marketId: "ETH-USD",
      timestamp: 1_700_000_000,
      seq: 1,
      side: "BUY",
      quantityBase: "1.5",
      priceQuotePerBase: "100.25",
      line: 2
    )
  end

  it "raises when required fields are missing" do
    row = {
      "trade_id" => "trade-1",
      "account_id" => "acc-1"
    }

    expect { described_class.new.call(row: row, line: 2) }.to raise_error(ArgumentError)
  end
end
