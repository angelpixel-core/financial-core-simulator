# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Engine::ValuationEngine do
  it "computes unrealized pnl as (snapshot - avgCost) * qty" do
    snapshot = {
      "prices" => [{ "marketId" => "ETH-USD", "priceQuotePerBase" => "150" }]
    }

    valuation = described_class.new(price_snapshot: snapshot)

    pos = FCS::Engine::Position.empty
    pos.apply_buy!(
      buy_qty: FCS::Types::Decimal18.from_string("2"),
      buy_price: FCS::Types::Decimal18.from_string("100")
    )

    unreal = valuation.unrealized_pnl_quote(market_id: "ETH-USD", position: pos)
    # (150 - 100) * 2 = 100
    expect(unreal.to_s).to eq("100.0")
  end
end
