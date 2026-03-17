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

  it "accepts the smallest positive quantity" do
    position = described_class.empty

    position.apply_buy!(buy_qty: d18("0.000000000000000001"), buy_price: d18("100"))

    expect(position.qty.to_s).to eq("0.000000000000000001")
  end

  it "accumulates fees and returns realized net quote" do
    position = described_class.empty

    expect(position.apply_fee!(d18("2.5"))).to be(position)
    expect(position.apply_fee!(d18("1.5"))).to be(position)

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

  it "keeps avg cost when partially sold" do
    position = described_class.empty

    position.apply_buy!(buy_qty: d18("2"), buy_price: d18("100"))
    position.apply_sell!(sell_qty: d18("1"), sell_price: d18("150"))

    expect(position.qty.to_s).to eq("1.0")
    expect(position.avg_cost.to_s).to eq("100.0")
  end

  it "rejects sells that would make the position negative" do
    position = described_class.empty

    expect do
      position.apply_sell!(sell_qty: d18("1"), sell_price: d18("100"))
    end.to raise_error(FCS::Error) { |error| expect(error.code).to eq(FCS::Errors::ERR_POSITION_NEGATIVE) }
  end

  it "rejects buys when position is already short" do
    position = described_class.new(
      qty: d18("-1"),
      avg_cost: d18("100"),
      realized_pnl_quote: d18("0"),
      fees_quote: d18("0")
    )

    expect do
      position.apply_buy!(buy_qty: d18("1"), buy_price: d18("100"))
    end.to raise_error(FCS::Error) { |error| expect(error.code).to eq(FCS::Errors::ERR_POSITION_NEGATIVE) }
  end

  it "returns self on buy and sell" do
    position = described_class.empty

    expect(position.apply_buy!(buy_qty: d18("1"), buy_price: d18("100"))).to be(position)
    expect(position.apply_sell!(sell_qty: d18("1"), sell_price: d18("110"))).to be(position)
  end

  it "includes quantity details when rejecting buy" do
    position = described_class.empty

    expect do
      position.apply_buy!(buy_qty: d18("0"), buy_price: d18("100"))
    end.to raise_error(FCS::Error) { |error|
      expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
      expect(error.message).to eq("BUY quantity must be > 0")
      expect(error.details).to eq(quantityBase: "0.0")
    }
  end

  it "rejects negative buy quantity" do
    position = described_class.empty

    expect do
      position.apply_buy!(buy_qty: d18("-1"), buy_price: d18("100"))
    end.to raise_error(FCS::Error) { |error|
      expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
      expect(error.details).to eq(quantityBase: "-1.0")
    }
  end

  it "includes long-only violation details on sell" do
    position = described_class.empty

    expect do
      position.apply_sell!(sell_qty: d18("1"), sell_price: d18("100"))
    end.to raise_error(FCS::Error) { |error|
      expect(error.code).to eq(FCS::Errors::ERR_POSITION_NEGATIVE)
      expect(error.message).to eq("SELL would make position negative")
      expect(error.details).to eq(qty: "0.0")
    }
  end

  it "respects injected error dependencies" do
    custom_errors = Module.new
    custom_errors.const_set(:ERR_VALIDATION, "CUSTOM_VALIDATION")
    custom_error_class = Class.new(FCS::Error)

    deps = FCS::Engine::Dependencies.new(
      FCS::Types::Decimal18,
      custom_error_class,
      custom_errors
    )

    position = described_class.empty(dependencies: deps)

    expect do
      position.apply_buy!(buy_qty: d18("0"), buy_price: d18("1"))
    end.to raise_error(custom_error_class) { |error|
      expect(error.code).to eq("CUSTOM_VALIDATION")
    }
  end
end
