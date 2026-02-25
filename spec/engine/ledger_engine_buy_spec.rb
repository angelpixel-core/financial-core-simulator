# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Engine::LedgerEngine do
  it "applies BUY trades and updates avg cost (average cost method)" do
    engine = described_class.new

    t1 = {
      "tradeId" => "t1",
      "accountId" => "acc-1",
      "marketId" => "ETH-USD",
      "timestamp" => 1,
      "seq" => 1,
      "side" => "BUY",
      "quantityBase" => "2",
      "priceQuotePerBase" => "100"
    }

    t2 = {
      "tradeId" => "t2",
      "accountId" => "acc-1",
      "marketId" => "ETH-USD",
      "timestamp" => 2,
      "seq" => 1,
      "side" => "BUY",
      "quantityBase" => "1",
      "priceQuotePerBase" => "160"
    }

    engine.apply_trade!(t1)
    engine.apply_trade!(t2)

    pos = engine.state.position_for(account_id: "acc-1", market_id: "ETH-USD")

    expect(pos.qty.to_s).to eq("3.0")
    # avg = (2*100 + 1*160)/3 = 120
    expect(pos.avg_cost.to_s).to eq("120.0")
  end
end
