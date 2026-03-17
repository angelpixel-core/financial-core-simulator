# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Engine::PositionFifo do
  def d18(value)
    FCS::Types::Decimal18.from_string(value)
  end

  it "starts empty with zeroed fields" do
    position = described_class.empty

    expect(position.qty.to_s).to eq("0.0")
    expect(position.avg_cost.to_s).to eq("0.0")
    expect(position.realized_pnl_quote.to_s).to eq("0.0")
    expect(position.fees_quote.to_s).to eq("0.0")
    expect(position).to be_a(described_class)
  end

  it "applies buys and recomputes weighted avg cost" do
    position = described_class.empty

    expect(position.apply_buy!(buy_qty: d18("2"), buy_price: d18("100"))).to be(position)
    expect(position.apply_buy!(buy_qty: d18("1"), buy_price: d18("160"))).to be(position)

    expect(position.qty.to_s).to eq("3.0")
    expect(position.avg_cost.to_s).to eq("120.0")
  end

  it "realizes pnl using FIFO lots on sell" do
    position = described_class.empty

    position.apply_buy!(buy_qty: d18("2"), buy_price: d18("100"))
    position.apply_buy!(buy_qty: d18("1"), buy_price: d18("120"))

    expect(position.apply_sell!(sell_qty: d18("2.5"), sell_price: d18("150"))).to be(position)

    # 2 @100 + 0.5 @120 = (50*2) + (30*0.5) = 115
    expect(position.realized_pnl_quote.to_s).to eq("115.0")
    expect(position.qty.to_s).to eq("0.5")
    expect(position.avg_cost.to_s).to eq("120.0")
  end

  it "keeps lot price for remaining quantity" do
    position = described_class.empty

    position.apply_buy!(buy_qty: d18("2"), buy_price: d18("100"))
    position.apply_buy!(buy_qty: d18("1"), buy_price: d18("120"))
    position.apply_sell!(sell_qty: d18("1"), sell_price: d18("150"))

    expect(position.qty.to_s).to eq("2.0")
    expect(position.avg_cost.to_s).to eq("110.0")
  end

  it "resets avg cost to zero when fully sold" do
    position = described_class.empty

    position.apply_buy!(buy_qty: d18("1"), buy_price: d18("100"))
    position.apply_sell!(sell_qty: d18("1"), sell_price: d18("110"))

    expect(position.qty.to_s).to eq("0.0")
    expect(position.avg_cost.to_s).to eq("0.0")
  end

  it "keeps avg cost when partially sold" do
    position = described_class.empty

    position.apply_buy!(buy_qty: d18("2"), buy_price: d18("100"))
    position.apply_sell!(sell_qty: d18("1"), sell_price: d18("120"))

    expect(position.qty.to_s).to eq("1.0")
    expect(position.avg_cost.to_s).to eq("100.0")
  end

  it "accumulates fees and returns realized net quote" do
    position = described_class.empty

    expect(position.apply_fee!(d18("1.25"))).to be(position)
    expect(position.apply_fee!(d18("0.75"))).to be(position)

    expect(position.fees_quote.to_s).to eq("2.0")
    expect(position.realized_net_quote.to_s).to eq("-2.0")
  end

  it "rejects sells that would make the position negative" do
    position = described_class.empty

    expect do
      position.apply_sell!(sell_qty: d18("1"), sell_price: d18("100"))
    end.to raise_error(FCS::Error) { |error|
      expect(error.code).to eq(FCS::Errors::ERR_POSITION_NEGATIVE)
      expect(error.message).to eq("SELL would make position negative")
      expect(error.details).to eq(qty: "0.0", sellQty: "1.0")
    }
  end

  it "reports sell qty in long-only violation details" do
    position = described_class.empty

    expect do
      position.apply_sell!(sell_qty: d18("1"), sell_price: d18("100"))
    end.to raise_error(FCS::Error) { |error|
      expect(error.message).to eq("SELL would make position negative")
      expect(error.details).to eq(qty: "0.0", sellQty: "1.0")
    }
  end

  it "returns self on sell" do
    position = described_class.empty

    position.apply_buy!(buy_qty: d18("1"), buy_price: d18("100"))
    expect(position.apply_sell!(sell_qty: d18("1"), sell_price: d18("110"))).to be(position)
  end
end
