# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Engine::LedgerState do
  it "builds and memoizes positions per account and market" do
    built = []
    builder = lambda do
      position = Object.new
      built << position
      position
    end

    state = described_class.new(position_builder: builder)

    first = state.position_for(account_id: "acc-1", market_id: "BTC-USD")
    second = state.position_for(account_id: "acc-1", market_id: "BTC-USD")
    third = state.position_for(account_id: "acc-2", market_id: "BTC-USD")

    expect(first).to be(second)
    expect(first).not_to be(third)
    expect(built.size).to eq(2)
  end

  it "uses the default position builder" do
    state = described_class.new

    position = state.position_for(account_id: "acc-1", market_id: "BTC-USD")

    expect(position).to be_a(FCS::Engine::Position)
    expect(position.qty).to be_a(FCS::Types::Decimal18)
  end

  it "propagates dependencies to the default position builder" do
    custom_errors = Module.new
    custom_errors.const_set(:ERR_VALIDATION, "CUSTOM_VALIDATION")
    custom_error_class = Class.new(FCS::Error)

    deps = FCS::Engine::Dependencies.new(
      FCS::Types::Decimal18,
      custom_error_class,
      custom_errors
    )

    state = described_class.new(dependencies: deps)
    position = state.position_for(account_id: "acc-1", market_id: "BTC-USD")

    expect do
      position.apply_buy!(buy_qty: FCS::Types::Decimal18.new(0), buy_price: FCS::Types::Decimal18.new(1))
    end.to raise_error(custom_error_class) { |error|
      expect(error.code).to eq("CUSTOM_VALIDATION")
    }
  end

  it "uses account and market to build distinct keys" do
    state = described_class.new(position_builder: -> { Object.new })

    state.position_for(account_id: "acc-1", market_id: "BTC-USD")
    state.position_for(account_id: "acc-1", market_id: "ETH-USD")
    state.position_for(account_id: "acc-2", market_id: "BTC-USD")

    expect(state.positions.keys).to contain_exactly(
      "acc-1|BTC-USD",
      "acc-1|ETH-USD",
      "acc-2|BTC-USD"
    )
  end
end
