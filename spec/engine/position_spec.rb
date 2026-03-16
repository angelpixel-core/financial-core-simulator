# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Engine::Position do
  def d18(value)
    FCS::Types::Decimal18.from_string(value)
  end

  it "rejects BUY with zero quantity defensively" do
    position = described_class.empty

    expect do
      position.apply_buy!(
        buy_qty: FCS::Types::Decimal18.new(0),
        buy_price: d18("100")
      )
    end.to raise_error(FCS::Error) { |error| expect(error.code).to eq(FCS::Errors::ERR_VALIDATION) }
  end

  it "computes weighted average cost on buys" do
    position = described_class.empty

    position.apply_buy!(buy_qty: d18("2"), buy_price: d18("100"))
    position.apply_buy!(buy_qty: d18("1"), buy_price: d18("160"))

    expect(position.qty.to_s).to eq("3.0")
    expect(position.avg_cost.to_s).to eq("120.0")
  end

  it "accumulates fees and returns realized net quote" do
    position = described_class.empty

    position.apply_fee!(d18("2.5"))
    position.apply_fee!(d18("1.5"))

    expect(position.fees_quote.to_s).to eq("4.0")
    expect(position.realized_net_quote.to_s).to eq("-4.0")
  end

  it "realizes pnl on sell and resets avg cost when flat" do
    position = described_class.empty

    position.apply_buy!(buy_qty: d18("2"), buy_price: d18("100"))
    position.apply_sell!(sell_qty: d18("2"), sell_price: d18("150"))

    expect(position.qty.to_s).to eq("0.0")
    expect(position.avg_cost.to_s).to eq("0.0")
    expect(position.realized_pnl_quote.to_s).to eq("100.0")
  end

  it "rejects sells that would make the position negative" do
    position = described_class.empty

    expect do
      position.apply_sell!(sell_qty: d18("1"), sell_price: d18("100"))
    end.to raise_error(FCS::Error) { |error| expect(error.code).to eq(FCS::Errors::ERR_POSITION_NEGATIVE) }
  end
end
