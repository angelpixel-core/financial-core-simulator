# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Engine::LedgerEngine do
  class SpyRiskEngine
    attr_reader :calls

    def initialize
      @calls = []
    end

    def pre_trade_check!(**kwargs)
      @calls << kwargs
    end
  end

  class SpyPosition
    attr_reader :buy_args, :sell_args, :fee_args, :qty

    def initialize(qty: "0", qty_object: nil)
      @qty = qty_object || FCS::Types::Decimal18.from_string(qty)
    end

    def apply_buy!(buy_qty:, buy_price:)
      @buy_args = {buy_qty: buy_qty, buy_price: buy_price}
    end

    def apply_sell!(sell_qty:, sell_price:)
      @sell_args = {sell_qty: sell_qty, sell_price: sell_price}
    end

    def apply_fee!(fee_quote)
      @fee_args = fee_quote
    end
  end

  def build_state(position = SpyPosition.new)
    Class.new do
      def initialize(position)
        @position = position
      end

      def position_for(*)
        @position
      end
    end.new(position)
  end

  def base_trade
    {
      "tradeId" => "t1",
      "accountId" => "acc-1",
      "marketId" => "ETH-USD",
      "timestamp" => 1,
      "seq" => 1,
      "side" => "BUY",
      "quantityBase" => "1.5",
      "priceQuotePerBase" => "10",
      "fee" => {"amountQuote" => "0.25"}
    }
  end

  it "passes full trade context to risk engine" do
    risk_engine = SpyRiskEngine.new
    position = SpyPosition.new
    state = build_state(position)

    engine = described_class.new(
      state: state,
      risk_engine: risk_engine,
      accounting_method: described_class::ACCOUNTING_METHOD_AVERAGE
    )

    trade = base_trade
    engine.apply_trade!(trade)

    expect(risk_engine.calls.size).to eq(1)
    expect(risk_engine.calls.first).to eq(
      account_id: "acc-1",
      market_id: "ETH-USD",
      side: "BUY",
      quantity: "1.5",
      price: "10",
      position: position,
      accounting_method: described_class::ACCOUNTING_METHOD_AVERAGE
    )
  end

  it "applies fees when enabled and fee amount is provided" do
    risk_engine = SpyRiskEngine.new
    position = SpyPosition.new
    state = build_state(position)

    engine = described_class.new(
      state: state,
      risk_engine: risk_engine,
      fee_enabled: true
    )

    engine.apply_trade!(base_trade)

    expect(position.fee_args).to be_a(FCS::Types::Decimal18)
    expect(position.fee_args.class.name).to eq("FCS::Types::Decimal18")
    expect(position.fee_args.to_s).to eq("0.25")
  end

  it "applies fees by default when enabled is not specified" do
    risk_engine = SpyRiskEngine.new
    position = SpyPosition.new
    state = build_state(position)

    engine = described_class.new(
      state: state,
      risk_engine: risk_engine
    )

    engine.apply_trade!(base_trade)

    expect(position.fee_args).to be_a(FCS::Types::Decimal18)
    expect(position.fee_args.to_s).to eq("0.25")
  end

  it "does not apply fees when disabled" do
    risk_engine = SpyRiskEngine.new
    position = SpyPosition.new
    state = build_state(position)

    engine = described_class.new(
      state: state,
      risk_engine: risk_engine,
      fee_enabled: false
    )

    engine.apply_trade!(base_trade)

    expect(position.fee_args).to be_nil
  end

  it "uses FCS::Types::Decimal18 even if local Types constant exists" do
    stub_const("FCS::Engine::LedgerEngine::Types", Module.new do
      const_set(:Decimal18, Class.new do
        def self.from_string(*)
          raise "unexpected decimal class"
        end
      end)
    end)

    risk_engine = SpyRiskEngine.new
    position = SpyPosition.new
    state = build_state(position)

    engine = described_class.new(
      state: state,
      risk_engine: risk_engine,
      fee_enabled: false
    )

    engine.apply_trade!(base_trade)

    expect(position.buy_args[:buy_qty].class.name).to eq("FCS::Types::Decimal18")
    expect(position.buy_args[:buy_price].class.name).to eq("FCS::Types::Decimal18")
  end

  it "applies sell using Decimal18 when inventory is sufficient" do
    position = SpyPosition.new(qty: "2.0")
    state = build_state(position)
    engine = described_class.new(state: state, risk_engine: SpyRiskEngine.new)

    sell = base_trade.merge(
      "tradeId" => "s1",
      "side" => "SELL",
      "quantityBase" => "1.0",
      "priceQuotePerBase" => "12"
    )

    engine.apply_trade!(sell)

    expect(position.sell_args[:sell_qty].class.name).to eq("FCS::Types::Decimal18")
    expect(position.sell_args[:sell_price].class.name).to eq("FCS::Types::Decimal18")
  end

  it "raises with validation error for unsupported side" do
    position = SpyPosition.new(qty: "2.0")
    state = build_state(position)
    engine = described_class.new(state: state, risk_engine: SpyRiskEngine.new)

    bad_trade = base_trade.merge("side" => "HOLD")
    allow(bad_trade).to receive(:[]).and_call_original
    allow(bad_trade).to receive(:[]).with("side").and_return("PENDING")
    allow(bad_trade).to receive(:[]).with("tradeId").and_return(nil)

    expect { engine.apply_trade!(bad_trade) }
      .to raise_error(FCS::Error) { |error|
        expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(error.message).to eq("Unsupported side")
        expect(error.details).to eq(side: "HOLD", tradeId: "t1")
      }
  end

  it "returns nil when fee is missing or malformed" do
    position = SpyPosition.new
    state = build_state(position)
    engine = described_class.new(state: state, risk_engine: SpyRiskEngine.new, fee_enabled: true)

    trade_no_fee = base_trade.dup.tap { |t| t.delete("fee") }
    engine.apply_trade!(trade_no_fee)
    expect(position.fee_args).to be_nil

    trade_bad_fee = base_trade.merge("fee" => "0.25")
    engine.apply_trade!(trade_bad_fee)
    expect(position.fee_args).to be_nil

    trade_no_amount = base_trade.merge("fee" => {})
    engine.apply_trade!(trade_no_amount)
    expect(position.fee_args).to be_nil

    fee_subclass = Class.new(Hash)
    trade_subclass_fee = base_trade.merge("fee" => fee_subclass["amountQuote" => "0.5"])
    engine.apply_trade!(trade_subclass_fee)
    expect(position.fee_args.to_s).to eq("0.5")
  end

  it "raises for unsupported accounting method" do
    expect do
      described_class.new(
        accounting_method: "UNKNOWN",
        error_klass: FCS::Error,
        errors: FCS::Errors
      )
    end.to raise_error(FCS::Error) do |error|
      expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
      expect(error.message).to eq("Unsupported accounting method")
      expect(error.details).to eq(accountingMethod: "UNKNOWN")
    end
  end

  it "builds FIFO positions when accounting method is FIFO" do
    engine = described_class.new(accounting_method: described_class::ACCOUNTING_METHOD_FIFO)
    position = engine.state.position_for(account_id: "acc-1", market_id: "ETH-USD")

    expect(position).to be_a(FCS::Engine::PositionFifo)
  end

  it "builds average positions when accounting method is average" do
    engine = described_class.new(accounting_method: described_class::ACCOUNTING_METHOD_AVERAGE)
    position = engine.state.position_for(account_id: "acc-1", market_id: "ETH-USD")

    expect(position).to be_a(FCS::Engine::Position)
  end

  it "provides a position builder for average accounting" do
    engine = described_class.new(accounting_method: described_class::ACCOUNTING_METHOD_AVERAGE)

    builder = engine.send(:position_builder_for, described_class::ACCOUNTING_METHOD_AVERAGE)

    expect(builder).to respond_to(:call)
    expect(builder.call).to be_a(FCS::Engine::Position)
  end

  it "injects a custom decimal class for trade parsing" do
    decimal_klass = Class.new do
      DecimalStub = Struct.new(:atoms) do
        delegate :to_s, to: :atoms
      end

      def self.from_string(value)
        DecimalStub.new(value.to_i)
      end
    end

    decimal_stub = decimal_klass.from_string("10")
    position = SpyPosition.new(qty_object: decimal_stub)
    state = build_state(position)
    engine = described_class.new(state: state, risk_engine: SpyRiskEngine.new, decimal_klass: decimal_klass)

    engine.apply_trade!(base_trade)

    expect(position.buy_args[:buy_qty].class).to eq(decimal_stub.class)
    expect(position.buy_args[:buy_price].class).to eq(decimal_stub.class)
  end

  it "uses custom error_klass and errors for unsupported side" do
    custom_errors = Module.new
    custom_errors.const_set(:ERR_VALIDATION, "CUSTOM_VALIDATION")
    custom_error_klass = Class.new(FCS::Error)

    engine = described_class.new(
      state: build_state(SpyPosition.new(qty: "2.0")),
      risk_engine: SpyRiskEngine.new,
      error_klass: custom_error_klass,
      errors: custom_errors
    )

    bad_trade = base_trade.merge("side" => "HOLD")

    expect { engine.apply_trade!(bad_trade) }
      .to raise_error(custom_error_klass) { |error|
        expect(error.code).to eq("CUSTOM_VALIDATION")
        expect(error.details).to eq(side: "HOLD", tradeId: "t1")
      }
  end

  it "raises when unsupported side tradeId is missing" do
    engine = described_class.new(state: build_state(SpyPosition.new(qty: "2.0")), risk_engine: SpyRiskEngine.new)
    bad_trade = base_trade.merge("side" => "HOLD")
    bad_trade.delete("tradeId")

    expect { engine.apply_trade!(bad_trade) }
      .to raise_error(KeyError)
  end

  it "uses risk_engine_klass for default risk engine" do
    risk_engine_klass = Class.new do
      def initialize(account_collateral:, risk_config:)
        @account_collateral = account_collateral
        @risk_config = risk_config
      end

      attr_reader :account_collateral, :risk_config
    end

    engine = described_class.new(
      account_collateral: {"acc-1" => FCS::Types::Decimal18.from_string("10")},
      max_leverage: FCS::Types::Decimal18.from_string("2"),
      risk_engine_klass: risk_engine_klass
    )

    risk_engine = engine.instance_variable_get(:@risk_engine)
    expect(risk_engine.account_collateral.keys).to eq(["acc-1"])
    expect(risk_engine.risk_config[:maxLeverage].atoms)
      .to eq(FCS::Types::Decimal18.from_string("2").atoms)
  end

  it "prefers fully qualified RiskEngine for defaults" do
    stub_const("FCS::Engine::LedgerEngine::RiskEngine", Class.new do
      def initialize(*)
      end
    end)

    local_engine = Module.new do
      const_set(:RiskEngine, Class.new do
        def initialize(*)
        end
      end)
    end

    stub_const("FCS::Engine::LedgerEngine::Engine", local_engine)

    engine = described_class.new

    expect(engine.instance_variable_get(:@risk_engine)).to be_a(FCS::Engine::RiskEngine)
    expect(engine.instance_variable_get(:@risk_engine)).not_to be_a(local_engine::RiskEngine)
  end

  it "prefers fully qualified Error for defaults" do
    stub_const("FCS::Engine::LedgerEngine::Error", Class.new(StandardError))

    position = SpyPosition.new(qty: "2.0")
    state = build_state(position)
    engine = described_class.new(state: state, risk_engine: SpyRiskEngine.new)

    bad_trade = base_trade.merge("side" => "HOLD")

    expect { engine.apply_trade!(bad_trade) }
      .to raise_error(FCS::Error)
  end

  it "prefers fully qualified Errors for defaults" do
    stub_const("FCS::Engine::LedgerEngine::Errors", Module.new do
      const_set(:ERR_VALIDATION, "LOCAL")
    end)

    position = SpyPosition.new(qty: "2.0")
    state = build_state(position)
    engine = described_class.new(state: state, risk_engine: SpyRiskEngine.new)

    bad_trade = base_trade.merge("side" => "HOLD")

    expect { engine.apply_trade!(bad_trade) }
      .to raise_error(FCS::Error) { |error|
        expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
      }
  end
end
