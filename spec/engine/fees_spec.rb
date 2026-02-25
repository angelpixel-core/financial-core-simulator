# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe "Fees in quote" do
  it "reduces net realized pnl by accumulated fees when enabled" do
    engine = FCS::Engine::LedgerEngine.new(fee_enabled: true)

    buy = {
      "tradeId" => "b1",
      "accountId" => "acc-1",
      "marketId" => "ETH-USD",
      "timestamp" => 1,
      "seq" => 1,
      "side" => "BUY",
      "quantityBase" => "2",
      "priceQuotePerBase" => "100",
      "fee" => { "amountQuote" => "1" }
    }

    sell = {
      "tradeId" => "s1",
      "accountId" => "acc-1",
      "marketId" => "ETH-USD",
      "timestamp" => 2,
      "seq" => 1,
      "side" => "SELL",
      "quantityBase" => "2",
      "priceQuotePerBase" => "110",
      "fee" => { "amountQuote" => "2" }
    }

    engine.apply_trade!(buy)
    engine.apply_trade!(sell)

    pos = engine.state.position_for(account_id: "acc-1", market_id: "ETH-USD")

    # realized = (110 - 100) * 2 = 20
    expect(pos.realized_pnl_quote.to_s).to eq("20.0")
    expect(pos.fees_quote.to_s).to eq("3.0")
    expect(pos.realized_net_quote.to_s).to eq("17.0")
  end

  it "ignores fee fields when fee model disabled" do
    engine = FCS::Engine::LedgerEngine.new(fee_enabled: false)

    buy = {
      "tradeId" => "b1",
      "accountId" => "acc-1",
      "marketId" => "ETH-USD",
      "timestamp" => 1,
      "seq" => 1,
      "side" => "BUY",
      "quantityBase" => "1",
      "priceQuotePerBase" => "100",
      "fee" => { "amountQuote" => "999" }
    }

    engine.apply_trade!(buy)

    pos = engine.state.position_for(account_id: "acc-1", market_id: "ETH-USD")
    expect(pos.fees_quote.to_s).to eq("0.0")
  end
end
