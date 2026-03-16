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

  it "updates snapshot price for market with decimal-string input" do
    snapshot = {
      "prices" => [{ "marketId" => "ETH-USD", "priceQuotePerBase" => "150" }]
    }

    valuation = described_class.new(price_snapshot: snapshot)
    valuation.update_price!(market_id: "ETH-USD", price_quote_per_base: "151.25")

    expect(valuation.snapshot_price_for("ETH-USD").to_s).to eq("151.25")
  end

  it "keeps Decimal18 precision when updating price" do
    snapshot = {
      "prices" => [{ "marketId" => "ETH-USD", "priceQuotePerBase" => "150" }]
    }

    valuation = described_class.new(price_snapshot: snapshot)
    precise_price = "151.123456789012345678"

    valuation.update_price!(market_id: "ETH-USD", price_quote_per_base: precise_price)

    expected = FCS::Types::Decimal18.from_string(precise_price)
    actual = valuation.snapshot_price_for("ETH-USD")

    expect(actual.to_s).to eq(expected.to_s)
  end

  it "raises when updating an unknown market" do
    snapshot = {
      "prices" => [{ "marketId" => "ETH-USD", "priceQuotePerBase" => "150" }]
    }

    valuation = described_class.new(price_snapshot: snapshot)

    expect do
      valuation.update_price!(market_id: "BTC-USD", price_quote_per_base: "151.25")
    end.to raise_error(FCS::Error) { |e|
      expect(e.code).to eq(FCS::Errors::ERR_UNKNOWN_REFERENCE)
    }
  end

  it "rejects invalid update_price! input for price_quote_per_base" do
    snapshot = {
      "prices" => [{ "marketId" => "ETH-USD", "priceQuotePerBase" => "150" }]
    }

    valuation = described_class.new(price_snapshot: snapshot)

    expect do
      valuation.update_price!(market_id: "ETH-USD", price_quote_per_base: 151.25)
    end.to raise_error(FCS::Error) { |e|
      expect(e.code).to eq(FCS::Errors::ERR_INVALID_NUMBER)
    }
  end

  it "rejects invalid decimal strings and zero values" do
    snapshot = {
      "prices" => [{ "marketId" => "ETH-USD", "priceQuotePerBase" => "150" }]
    }

    valuation = described_class.new(price_snapshot: snapshot)

    expect do
      valuation.update_price!(market_id: "ETH-USD", price_quote_per_base: "15a.25")
    end.to raise_error(FCS::Error) { |e|
      expect(e.code).to eq(FCS::Errors::ERR_INVALID_NUMBER)
    }

    expect do
      valuation.update_price!(market_id: "ETH-USD", price_quote_per_base: "0")
    end.to raise_error(FCS::Error) { |e|
      expect(e.code).to eq(FCS::Errors::ERR_INVALID_NUMBER)
    }
  end
end
