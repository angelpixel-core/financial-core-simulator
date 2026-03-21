# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Engine::RiskEngine do
  let(:position) { FCS::Engine::Position.empty }

  class StubPosition
    def initialize(qty:, realized_net_quote:)
      @qty = qty
      @realized_net_quote = realized_net_quote
    end

    attr_reader :qty, :realized_net_quote
  end

  class StubState
    def initialize(positions)
      @positions = positions
    end

    attr_reader :positions
  end

  class StubValuation
    def initialize(snapshot_prices:, unrealized_pnls:)
      @snapshot_prices = snapshot_prices
      @unrealized_pnls = unrealized_pnls
      @positions_used = []
    end

    attr_reader :positions_used

    def snapshot_price_for(market_id)
      @snapshot_prices.fetch(market_id)
    end

    def unrealized_pnl_quote(market_id:, position:)
      @positions_used << position
      @unrealized_pnls.fetch(market_id)
    end
  end

  it "rejects FIFO short selling" do
    engine = described_class.new(
      account_collateral: {"acc-1" => FCS::Types::Decimal18.from_string("100")},
      risk_config: {maxLeverage: FCS::Types::Decimal18.from_string("2")}
    )

    expect do
      engine.pre_trade_check!(
        account_id: "acc-1",
        market_id: "ETH-USD",
        side: "SELL",
        quantity: "1",
        price: "100",
        position: position,
        accounting_method: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_FIFO
      )
    end.to raise_error(FCS::Error) { |e| expect(e.code).to eq(FCS::Errors::ERR_RISK_REJECTION) }
  end

  it "uses fully qualified LedgerEngine constants" do
    stub_const("FCS::Engine::RiskEngine::LedgerEngine", Class.new do
      const_set(:ACCOUNTING_METHOD_FIFO, "FIFO_LOCAL")
    end)

    engine = described_class.new(
      account_collateral: {"acc-1" => FCS::Types::Decimal18.from_string("100")},
      risk_config: {maxLeverage: FCS::Types::Decimal18.from_string("2")}
    )

    expect do
      engine.pre_trade_check!(
        account_id: "acc-1",
        market_id: "ETH-USD",
        side: "SELL",
        quantity: "1",
        price: "100",
        position: position,
        accounting_method: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_FIFO
      )
    end.to raise_error(FCS::Error)
  end

  it "does not use nested Engine::LedgerEngine constants" do
    stub_const("FCS::Engine::RiskEngine::Engine", Module.new do
      const_set(:LedgerEngine, Class.new do
        const_set(:ACCOUNTING_METHOD_FIFO, "FIFO_LOCAL")
      end)
    end)

    engine = described_class.new(
      account_collateral: {"acc-1" => FCS::Types::Decimal18.from_string("100")},
      risk_config: {maxLeverage: FCS::Types::Decimal18.from_string("2")}
    )

    expect do
      engine.pre_trade_check!(
        account_id: "acc-1",
        market_id: "ETH-USD",
        side: "SELL",
        quantity: "1",
        price: "100",
        position: position,
        accounting_method: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_FIFO
      )
    end.to raise_error(FCS::Error)
  end

  it "rejects short selling when leverage config is missing" do
    engine = described_class.new(account_collateral: {}, risk_config: {})

    expect do
      engine.pre_trade_check!(
        account_id: "acc-1",
        market_id: "ETH-USD",
        side: "SELL",
        quantity: "1",
        price: "100",
        position: position,
        accounting_method: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_AVERAGE
      )
    end.to raise_error(FCS::Error) { |e|
      expect(e.code).to eq(FCS::Errors::ERR_RISK_CONFIG_INVALID)
      expect(e.message).to eq("Short selling requires collateralQuote and riskModel.maxLeverage")
      expect(e.details).to eq(accountId: "acc-1")
    }
  end

  it "rejects trade when projected notional exceeds leverage limit" do
    engine = described_class.new(
      account_collateral: {"acc-1" => FCS::Types::Decimal18.from_string("100")},
      risk_config: {maxLeverage: FCS::Types::Decimal18.from_string("2")}
    )

    expect do
      engine.pre_trade_check!(
        account_id: "acc-1",
        market_id: "ETH-USD",
        side: "SELL",
        quantity: "3",
        price: "100",
        position: position,
        accounting_method: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_AVERAGE
      )
    end.to raise_error(FCS::Error) { |e|
      expect(e.code).to eq(FCS::Errors::ERR_RISK_REJECTION)
      expect(e.message).to eq("Leverage limit exceeded")
      expect(e.details).to eq(
        accountId: "acc-1",
        marketId: "ETH-USD",
        projectedNotionalQuote: FCS::Types::Decimal18.from_string("300").to_s,
        collateralQuote: FCS::Types::Decimal18.from_string("100").to_s,
        maxLeverage: FCS::Types::Decimal18.from_string("2").to_s,
        reason: "MAX_LEVERAGE_EXCEEDED"
      )
    }
  end

  it "returns deterministic liquidation candidates ordered by severity" do
    engine = described_class.new(
      account_collateral: {},
      risk_config: {maintenanceMarginRatio: FCS::Types::Decimal18.from_string("0.25")}
    )

    health = {
      "acc-b" => {
        status: FCS::Engine::RiskEngine::STATUS_LIQUIDATABLE,
        candidates: [
          {
            account_id: "acc-b",
            market_id: "ETH-USD",
            severity: FCS::Types::Decimal18.from_string("360"),
            seq: 0
          }
        ]
      },
      "acc-a" => {
        status: FCS::Engine::RiskEngine::STATUS_LIQUIDATABLE,
        candidates: [
          {
            account_id: "acc-a",
            market_id: "ETH-USD",
            severity: FCS::Types::Decimal18.from_string("120"),
            seq: 0
          }
        ]
      },
      "acc-c" => {
        status: FCS::Engine::RiskEngine::STATUS_HEALTHY,
        candidates: []
      }
    }

    candidates = engine.liquidation_candidates(health)

    expect(candidates.map { |c| c[:account_id] }).to eq(%w[acc-b acc-a])
  end

  it "allows long-only trades without collateral" do
    engine = described_class.new(account_collateral: {}, risk_config: {})

    expect(
      engine.pre_trade_check!(
        account_id: "acc-1",
        market_id: "ETH-USD",
        side: "BUY",
        quantity: "1",
        price: "100",
        position: position,
        accounting_method: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_AVERAGE
      )
    ).to be(true)
  end

  it "returns true when projected notional remains within leverage" do
    engine = described_class.new(
      account_collateral: {"acc-1" => FCS::Types::Decimal18.from_string("100")},
      risk_config: {maxLeverage: FCS::Types::Decimal18.from_string("3")}
    )

    expect(
      engine.pre_trade_check!(
        account_id: "acc-1",
        market_id: "ETH-USD",
        side: "SELL",
        quantity: "1",
        price: "100",
        position: position,
        accounting_method: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_AVERAGE
      )
    ).to be(true)
  end

  it "raises with detailed FIFO rejection" do
    engine = described_class.new(
      account_collateral: {"acc-1" => FCS::Types::Decimal18.from_string("100")},
      risk_config: {maxLeverage: FCS::Types::Decimal18.from_string("2")}
    )

    expect do
      engine.pre_trade_check!(
        account_id: "acc-1",
        market_id: "ETH-USD",
        side: "SELL",
        quantity: "1",
        price: "100",
        position: position,
        accounting_method: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_FIFO
      )
    end.to raise_error(FCS::Error) { |e|
      expect(e.code).to eq(FCS::Errors::ERR_RISK_REJECTION)
      expect(e.message).to eq("Short selling is not supported with FIFO accounting")
      expect(e.details).to eq(
        accountingMethod: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_FIFO,
        reason: "FIFO_SHORT_FORBIDDEN"
      )
    }
  end

  it "raises when collateral is zero" do
    engine = described_class.new(
      account_collateral: {"acc-1" => FCS::Types::Decimal18.from_string("0")},
      risk_config: {maxLeverage: FCS::Types::Decimal18.from_string("2")}
    )

    expect do
      engine.pre_trade_check!(
        account_id: "acc-1",
        market_id: "ETH-USD",
        side: "SELL",
        quantity: "1",
        price: "100",
        position: position,
        accounting_method: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_AVERAGE
      )
    end.to raise_error(FCS::Error) { |e|
      expect(e.code).to eq(FCS::Errors::ERR_RISK_CONFIG_INVALID)
      expect(e.message).to eq("Short selling requires collateralQuote and riskModel.maxLeverage")
      expect(e.details).to eq(accountId: "acc-1")
    }
  end

  it "normalizes risk config keys and coerces string values" do
    engine = described_class.new(
      account_collateral: {},
      risk_config: {"maxLeverage" => "2", :maintenanceMarginRatio => "0.25"}
    )

    risk_config = engine.instance_variable_get(:@risk_config)

    expect(risk_config.keys).to contain_exactly(:max_leverage, :maintenance_margin_ratio)
    expect(risk_config[:max_leverage]).to be_a(FCS::Types::Decimal18)
    expect(risk_config[:maintenance_margin_ratio]).to be_a(FCS::Types::Decimal18)
    expect(risk_config[:max_leverage].atoms)
      .to eq(FCS::Types::Decimal18.from_string("2").atoms)
    expect(risk_config[:maintenance_margin_ratio].atoms)
      .to eq(FCS::Types::Decimal18.from_string("0.25").atoms)
  end

  it "preserves non-string config values" do
    leverage = FCS::Types::Decimal18.from_string("2")
    engine = described_class.new(
      account_collateral: {},
      risk_config: {maxLeverage: leverage, maintenanceMarginRatio: 5}
    )

    risk_config = engine.instance_variable_get(:@risk_config)

    expect(risk_config[:max_leverage]).to equal(leverage)
    expect(risk_config[:maintenance_margin_ratio]).to eq(5)
  end

  it "normalizes config via to_h" do
    config = Class.new do
      def to_h
        {"maxLeverage" => "2"}
      end
    end.new

    engine = described_class.new(account_collateral: {}, risk_config: config)

    risk_config = engine.instance_variable_get(:@risk_config)
    expect(risk_config[:max_leverage].atoms)
      .to eq(FCS::Types::Decimal18.from_string("2").atoms)
  end

  it "coerces String subclasses in config values" do
    custom_string = Class.new(String).new("3")
    engine = described_class.new(
      account_collateral: {},
      risk_config: {maxLeverage: custom_string}
    )

    risk_config = engine.instance_variable_get(:@risk_config)

    expect(risk_config[:max_leverage]).to be_a(FCS::Types::Decimal18)
  end

  it "normalizes collateral values using Decimal18" do
    engine = described_class.new(
      account_collateral: {"acc-1" => "10"},
      risk_config: {}
    )

    collateral = engine.instance_variable_get(:@account_collateral)

    expect(collateral["acc-1"]).to be_a(FCS::Types::Decimal18)
    expect(collateral["acc-1"].atoms)
      .to eq(FCS::Types::Decimal18.from_string("10").atoms)
  end

  it "evaluates account health with maintenance and candidates" do
    engine = described_class.new(
      account_collateral: {"acc-1" => FCS::Types::Decimal18.from_string("100")},
      risk_config: {maintenanceMarginRatio: FCS::Types::Decimal18.from_string("0.1")}
    )

    positions = {
      "acc-0|XRP-USD" => StubPosition.new(
        qty: FCS::Types::Decimal18.from_string("0"),
        realized_net_quote: FCS::Types::Decimal18.from_string("0")
      ),
      "acc-1|ETH-USD" => StubPosition.new(
        qty: FCS::Types::Decimal18.from_string("-2"),
        realized_net_quote: FCS::Types::Decimal18.from_string("5")
      ),
      "acc-2|BTC-USD" => StubPosition.new(
        qty: FCS::Types::Decimal18.from_string("3"),
        realized_net_quote: FCS::Types::Decimal18.from_string("0")
      ),
      "acc-3|DOGE-USD" => StubPosition.new(
        qty: FCS::Types::Decimal18.from_string("-0.0000000000000001"),
        realized_net_quote: FCS::Types::Decimal18.from_string("0")
      ),
      "acc-4|ETH|USD" => StubPosition.new(
        qty: FCS::Types::Decimal18.from_string("-1"),
        realized_net_quote: FCS::Types::Decimal18.from_string("0")
      )
    }
    state = StubState.new(positions)
    valuation = StubValuation.new(
      snapshot_prices: {
        "XRP-USD" => FCS::Types::Decimal18.from_string("1"),
        "ETH-USD" => FCS::Types::Decimal18.from_string("50"),
        "BTC-USD" => FCS::Types::Decimal18.from_string("10"),
        "DOGE-USD" => FCS::Types::Decimal18.from_string("1"),
        "ETH|USD" => FCS::Types::Decimal18.from_string("2")
      },
      unrealized_pnls: {
        "XRP-USD" => FCS::Types::Decimal18.from_string("0"),
        "ETH-USD" => FCS::Types::Decimal18.from_string("1"),
        "BTC-USD" => FCS::Types::Decimal18.from_string("-2"),
        "DOGE-USD" => FCS::Types::Decimal18.from_string("0"),
        "ETH|USD" => FCS::Types::Decimal18.from_string("0")
      }
    )

    health = engine.evaluate_accounts!(state: state, valuation: valuation)
    expect(health).to be_a(Hash)
    expect(health.keys).to contain_exactly("acc-0", "acc-1", "acc-2", "acc-3", "acc-4")

    acc1 = health.fetch("acc-1")
    expect(acc1.keys).to contain_exactly(:maintenance_margin_quote, :equity_quote, :margin_ratio, :status, :candidates)
    expect(acc1[:maintenance_margin_quote].atoms)
      .to eq(FCS::Types::Decimal18.from_string("10").atoms)
    expect(acc1[:equity_quote].atoms)
      .to eq(FCS::Types::Decimal18.from_string("106").atoms)
    expect(acc1[:margin_ratio].atoms)
      .to eq((acc1[:equity_quote] / acc1[:maintenance_margin_quote]).atoms)
    expect(acc1[:status]).to eq(FCS::Engine::RiskEngine::STATUS_HEALTHY)
    expect(acc1[:candidates].size).to eq(1)
    candidate = acc1[:candidates].first
    expect(candidate[:account_id]).to eq("acc-1")
    expect(candidate[:market_id]).to eq("ETH-USD")
    expect(candidate[:seq]).to eq(0)
    expect(candidate[:severity].atoms)
      .to eq(FCS::Types::Decimal18.from_string("100").atoms)

    acc2 = health.fetch("acc-2")
    expect(acc2.keys).to contain_exactly(:maintenance_margin_quote, :equity_quote, :margin_ratio, :status, :candidates)
    expect(acc2[:maintenance_margin_quote].atoms)
      .to eq(FCS::Types::Decimal18.from_string("3").atoms)
    expect(acc2[:equity_quote].atoms)
      .to eq(FCS::Types::Decimal18.from_string("-2").atoms)
    expect(acc2[:margin_ratio].atoms)
      .to eq((acc2[:equity_quote] / acc2[:maintenance_margin_quote]).atoms)
    expect(acc2[:status]).to eq(FCS::Engine::RiskEngine::STATUS_LIQUIDATABLE)
    expect(acc2[:candidates]).to eq([])

    acc0 = health.fetch("acc-0")
    expect(acc0.keys).to contain_exactly(:maintenance_margin_quote, :equity_quote, :margin_ratio, :status, :candidates)
    expect(acc0[:maintenance_margin_quote].atoms).to eq(FCS::Types::Decimal18.new(0).atoms)
    expect(acc0[:equity_quote].atoms).to eq(FCS::Types::Decimal18.new(0).atoms)
    expect(acc0[:margin_ratio]).to be_nil
    expect(acc0[:status]).to eq(FCS::Engine::RiskEngine::STATUS_HEALTHY)
    expect(acc0[:candidates]).to eq([])

    acc3 = health.fetch("acc-3")
    expect(acc3.keys).to contain_exactly(:maintenance_margin_quote, :equity_quote, :margin_ratio, :status, :candidates)
    expect(acc3[:margin_ratio].atoms).to eq(FCS::Types::Decimal18.new(0).atoms)
    expect(acc3[:status]).to eq(FCS::Engine::RiskEngine::STATUS_LIQUIDATABLE)
    expect(acc3[:candidates].size).to eq(1)

    acc4 = health.fetch("acc-4")
    expect(acc4.keys).to contain_exactly(:maintenance_margin_quote, :equity_quote, :margin_ratio, :status, :candidates)
    expect(acc4[:margin_ratio].atoms).to eq(FCS::Types::Decimal18.new(0).atoms)
    expect(acc4[:status]).to eq(FCS::Engine::RiskEngine::STATUS_LIQUIDATABLE)
    expect(acc4[:candidates].first[:market_id]).to eq("ETH|USD")

    expect(valuation.positions_used).to include(positions["acc-1|ETH-USD"], positions["acc-2|BTC-USD"])
  end

  it "skips maintenance when ratio is missing" do
    engine = described_class.new(account_collateral: {}, risk_config: {})
    positions = {
      "acc-1|ETH-USD" => StubPosition.new(
        qty: FCS::Types::Decimal18.from_string("-0.000000000000000001"),
        realized_net_quote: FCS::Types::Decimal18.from_string("0")
      )
    }
    state = StubState.new(positions)
    valuation = StubValuation.new(
      snapshot_prices: {"ETH-USD" => FCS::Types::Decimal18.from_string("10")},
      unrealized_pnls: {"ETH-USD" => FCS::Types::Decimal18.from_string("0")}
    )

    health = engine.evaluate_accounts!(state: state, valuation: valuation)

    acc1 = health.fetch("acc-1")
    expect(acc1[:maintenance_margin_quote].atoms).to eq(FCS::Types::Decimal18.new(0).atoms)
    expect(acc1[:margin_ratio]).to be_nil
    expect(acc1[:status]).to eq(FCS::Engine::RiskEngine::STATUS_HEALTHY)
    expect(acc1[:candidates].size).to eq(1)
  end

  it "treats zero maintenance as healthy with nil margin ratio" do
    engine = described_class.new(account_collateral: {}, risk_config: {})
    state = StubState.new({})
    valuation = StubValuation.new(snapshot_prices: {}, unrealized_pnls: {})

    health = engine.evaluate_accounts!(state: state, valuation: valuation)

    expect(health).to eq({})
  end

  it "orders liquidation candidates by severity then account, market, seq" do
    engine = described_class.new(account_collateral: {}, risk_config: {})

    health = {
      "acc-b" => {
        status: FCS::Engine::RiskEngine::STATUS_LIQUIDATABLE,
        candidates: [
          {account_id: "acc-b", market_id: "AAA-USD", severity: FCS::Types::Decimal18.from_string("10"), seq: 0},
          {account_id: "acc-b", market_id: "BTC-USD", severity: FCS::Types::Decimal18.from_string("10"), seq: 1}
        ]
      },
      "acc-a" => {
        status: FCS::Engine::RiskEngine::STATUS_LIQUIDATABLE,
        candidates: [
          {account_id: "acc-a", market_id: "AAA-USD", severity: FCS::Types::Decimal18.from_string("10"), seq: 1},
          {account_id: "acc-a", market_id: "BBB-USD", severity: FCS::Types::Decimal18.from_string("10"), seq: 2},
          {account_id: "acc-a", market_id: "BBB-USD", severity: FCS::Types::Decimal18.from_string("10"), seq: 0}
        ]
      },
      "acc-c" => {
        status: FCS::Engine::RiskEngine::STATUS_LIQUIDATABLE,
        candidates: [
          {account_id: "acc-c", market_id: "ETH-USD", severity: FCS::Types::Decimal18.from_string("11"), seq: 0}
        ]
      }
    }

    ordered = engine.liquidation_candidates(health)

    expect(ordered.map { |c| [c[:account_id], c[:market_id], c[:seq]] }).to eq(
      [
        ["acc-c", "ETH-USD", 0],
        ["acc-a", "AAA-USD", 1],
        ["acc-a", "BBB-USD", 0],
        ["acc-a", "BBB-USD", 2],
        ["acc-b", "AAA-USD", 0],
        ["acc-b", "BTC-USD", 1]
      ]
    )
  end

  it "filters liquidation candidates to liquidatable entries" do
    engine = described_class.new(account_collateral: {}, risk_config: {})

    health = {
      "acc-a" => {
        status: FCS::Engine::RiskEngine::STATUS_HEALTHY,
        candidates: [
          {account_id: "acc-a", market_id: "ETH-USD", severity: FCS::Types::Decimal18.from_string("10"), seq: 0}
        ]
      },
      "acc-b" => {
        status: FCS::Engine::RiskEngine::STATUS_LIQUIDATABLE,
        candidates: [
          {account_id: "acc-b", market_id: "ETH-USD", severity: FCS::Types::Decimal18.from_string("20"), seq: 0}
        ]
      }
    }

    candidates = engine.liquidation_candidates(health)

    expect(candidates.map { |c| c[:account_id] }).to eq(["acc-b"])
  end

  it "ignores entries without status" do
    engine = described_class.new(account_collateral: {}, risk_config: {})

    health = {
      "acc-a" => {
        candidates: [
          {account_id: "acc-a", market_id: "ETH-USD", severity: FCS::Types::Decimal18.from_string("10"), seq: 0}
        ]
      }
    }

    expect(engine.liquidation_candidates(health)).to eq([])
  end

  it "raises when liquidatable entries omit candidates" do
    engine = described_class.new(account_collateral: {}, risk_config: {})

    health = {
      "acc-a" => {status: FCS::Engine::RiskEngine::STATUS_LIQUIDATABLE}
    }

    expect { engine.liquidation_candidates(health) }.to raise_error(NoMethodError)
  end

  it "computes projected qty atoms for BUY, SELL, and other" do
    engine = described_class.new(account_collateral: {}, risk_config: {})
    qty = FCS::Types::Decimal18.from_string("2")

    position_with_qty = StubPosition.new(
      qty: FCS::Types::Decimal18.from_string("5"),
      realized_net_quote: FCS::Types::Decimal18.from_string("0")
    )

    expect(engine.send(:projected_qty_atoms, position: position_with_qty, side: "BUY", quantity: qty))
      .to eq(position_with_qty.qty.atoms + qty.atoms)
    expect(engine.send(:projected_qty_atoms, position: position, side: "SELL", quantity: qty))
      .to eq(position.qty.atoms - qty.atoms)
    expect(engine.send(:projected_qty_atoms, position: position, side: "HOLD", quantity: qty))
      .to eq(position.qty.atoms)
  end

  it "computes margin ratio and status thresholds" do
    engine = described_class.new(account_collateral: {}, risk_config: {})
    maintenance = FCS::Types::Decimal18.from_string("10")
    equity = FCS::Types::Decimal18.from_string("5")

    expect(engine.send(:margin_ratio, maintenance: FCS::Types::Decimal18.new(0), equity: equity)).to be_nil
    expect(engine.send(:margin_ratio, maintenance: maintenance, equity: equity).to_s).to eq("0.5")

    expect(engine.send(:status_for, maintenance: FCS::Types::Decimal18.new(0), equity: equity))
      .to eq(FCS::Engine::RiskEngine::STATUS_HEALTHY)
    expect(engine.send(:status_for, maintenance: maintenance, equity: FCS::Types::Decimal18.new(0)))
      .to eq(FCS::Engine::RiskEngine::STATUS_LIQUIDATABLE)
    expect(engine.send(:status_for, maintenance: maintenance, equity: equity))
      .to eq(FCS::Engine::RiskEngine::STATUS_MARGIN_CALL)
  end

  it "treats equity slightly above zero as margin call" do
    engine = described_class.new(account_collateral: {}, risk_config: {})
    maintenance = FCS::Types::Decimal18.from_string("10")
    equity = FCS::Types::Decimal18.from_string("0.000000000000000001")

    expect(engine.send(:status_for, maintenance: maintenance, equity: equity))
      .to eq(FCS::Engine::RiskEngine::STATUS_MARGIN_CALL)
  end

  it "coerces Decimal18 subclasses and preserves FCS::Types::Decimal18" do
    engine = described_class.new(account_collateral: {}, risk_config: {})
    custom_decimal = Class.new(FCS::Types::Decimal18)
    value = custom_decimal.new(10)

    stub_const("FCS::Engine::RiskEngine::Types", Module.new)
    stub_const("FCS::Engine::RiskEngine::Types::Decimal18", Class.new do
      def self.from_string(_)
        :local_decimal
      end
    end)

    expect(engine.send(:coerce_decimal18, value)).to equal(value)

    from_string = engine.send(:coerce_decimal18, "1.5")
    expect(from_string).to be_a(FCS::Types::Decimal18)
    expect(from_string).not_to eq(:local_decimal)
  end

  it "accepts String subclasses as numeric inputs" do
    engine = described_class.new(account_collateral: {}, risk_config: {})
    custom_string = Class.new(String).new("1.25")

    value = engine.send(:coerce_decimal18, custom_string)

    expect(value).to be_a(FCS::Types::Decimal18)
  end

  it "returns Decimal18 zero from fully qualified namespace" do
    stub_const("FCS::Engine::RiskEngine::Types", Module.new do
      const_set(:Decimal18, Class.new)
    end)

    engine = described_class.new(account_collateral: {}, risk_config: {})

    expect(engine.send(:zero)).to be_a(FCS::Types::Decimal18)
  end

  it "treats projected qty zero as not short even without config" do
    engine = described_class.new(account_collateral: {}, risk_config: {})
    position_with_qty = StubPosition.new(
      qty: FCS::Types::Decimal18.from_string("1"),
      realized_net_quote: FCS::Types::Decimal18.from_string("0")
    )

    expect(
      engine.pre_trade_check!(
        account_id: "acc-1",
        market_id: "ETH-USD",
        side: "SELL",
        quantity: "1",
        price: "100",
        position: position_with_qty,
        accounting_method: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_AVERAGE
      )
    ).to be(true)
  end

  it "treats tiny negative projected qty as short" do
    engine = described_class.new(account_collateral: {}, risk_config: {})

    expect do
      engine.pre_trade_check!(
        account_id: "acc-1",
        market_id: "ETH-USD",
        side: "SELL",
        quantity: "0.000000000000000001",
        price: "100",
        position: position,
        accounting_method: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_AVERAGE
      )
    end.to raise_error(FCS::Error) { |e| expect(e.code).to eq(FCS::Errors::ERR_RISK_CONFIG_INVALID) }
  end

  it "requires max leverage when collateral is present" do
    engine = described_class.new(
      account_collateral: {"acc-1" => FCS::Types::Decimal18.from_string("10")},
      risk_config: {}
    )

    expect do
      engine.pre_trade_check!(
        account_id: "acc-1",
        market_id: "ETH-USD",
        side: "SELL",
        quantity: "1",
        price: "100",
        position: position,
        accounting_method: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_AVERAGE
      )
    end.to raise_error(FCS::Error) { |e| expect(e.code).to eq(FCS::Errors::ERR_RISK_CONFIG_INVALID) }
  end

  it "requires collateral when max leverage is present" do
    engine = described_class.new(
      account_collateral: {},
      risk_config: {maxLeverage: FCS::Types::Decimal18.from_string("2")}
    )

    expect do
      engine.pre_trade_check!(
        account_id: "acc-1",
        market_id: "ETH-USD",
        side: "SELL",
        quantity: "1",
        price: "100",
        position: position,
        accounting_method: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_AVERAGE
      )
    end.to raise_error(FCS::Error) { |e| expect(e.code).to eq(FCS::Errors::ERR_RISK_CONFIG_INVALID) }
  end

  it "allows leverage when projected notional is below max" do
    engine = described_class.new(
      account_collateral: {"acc-1" => FCS::Types::Decimal18.from_string("100")},
      risk_config: {maxLeverage: FCS::Types::Decimal18.from_string("2")}
    )

    expect(
      engine.pre_trade_check!(
        account_id: "acc-1",
        market_id: "ETH-USD",
        side: "SELL",
        quantity: "1.5",
        price: "100",
        position: position,
        accounting_method: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_AVERAGE
      )
    ).to be(true)
  end

  it "allows projected notional equal to max" do
    engine = described_class.new(
      account_collateral: {"acc-1" => FCS::Types::Decimal18.from_string("100")},
      risk_config: {maxLeverage: FCS::Types::Decimal18.from_string("2")}
    )

    expect(
      engine.pre_trade_check!(
        account_id: "acc-1",
        market_id: "ETH-USD",
        side: "SELL",
        quantity: "2",
        price: "100",
        position: position,
        accounting_method: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_AVERAGE
      )
    ).to be(true)
  end

  it "uses fully qualified Decimal18 for projected notional" do
    stub_const("FCS::Engine::RiskEngine::Types", Module.new do
      const_set(:Decimal18, Class.new do
        def self.new(*)
          raise "local decimal should not be used"
        end
      end)
    end)

    engine = described_class.new(
      account_collateral: {"acc-1" => FCS::Types::Decimal18.from_string("100")},
      risk_config: {maxLeverage: FCS::Types::Decimal18.from_string("2")}
    )

    expect(
      engine.pre_trade_check!(
        account_id: "acc-1",
        market_id: "ETH-USD",
        side: "SELL",
        quantity: "1",
        price: "100",
        position: position,
        accounting_method: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_AVERAGE
      )
    ).to be(true)
  end

  it "uses fully qualified Error and Errors for invalid values" do
    stub_const("FCS::Engine::RiskEngine::Error", Class.new(StandardError))
    stub_const("FCS::Engine::RiskEngine::Errors", Module.new do
      const_set(:ERR_RISK_CONFIG_INVALID, "LOCAL")
    end)

    engine = described_class.new(account_collateral: {}, risk_config: {})

    expect { engine.send(:coerce_decimal18, 123) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_RISK_CONFIG_INVALID)
      }
  end

  it "uses fully qualified Error and Errors for FIFO rejection" do
    stub_const("FCS::Engine::RiskEngine::Error", Class.new(StandardError))
    stub_const("FCS::Engine::RiskEngine::Errors", Module.new do
      const_set(:ERR_RISK_REJECTION, "LOCAL")
    end)

    engine = described_class.new(
      account_collateral: {"acc-1" => FCS::Types::Decimal18.from_string("100")},
      risk_config: {maxLeverage: FCS::Types::Decimal18.from_string("2")}
    )

    expect do
      engine.pre_trade_check!(
        account_id: "acc-1",
        market_id: "ETH-USD",
        side: "SELL",
        quantity: "1",
        price: "100",
        position: position,
        accounting_method: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_FIFO
      )
    end.to raise_error(FCS::Error) { |e|
      expect(e.code).to eq(FCS::Errors::ERR_RISK_REJECTION)
    }
  end

  it "uses fully qualified Error and Errors for leverage rejection" do
    stub_const("FCS::Engine::RiskEngine::Error", Class.new(StandardError))
    stub_const("FCS::Engine::RiskEngine::Errors", Module.new do
      const_set(:ERR_RISK_REJECTION, "LOCAL")
    end)

    engine = described_class.new(
      account_collateral: {"acc-1" => FCS::Types::Decimal18.from_string("100")},
      risk_config: {maxLeverage: FCS::Types::Decimal18.from_string("2")}
    )

    expect do
      engine.pre_trade_check!(
        account_id: "acc-1",
        market_id: "ETH-USD",
        side: "SELL",
        quantity: "3",
        price: "100",
        position: position,
        accounting_method: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_AVERAGE
      )
    end.to raise_error(FCS::Error) { |e|
      expect(e.code).to eq(FCS::Errors::ERR_RISK_REJECTION)
    }
  end

  it "uses fully qualified Error and Errors for invalid short config" do
    stub_const("FCS::Engine::RiskEngine::Error", Class.new(StandardError))
    stub_const("FCS::Engine::RiskEngine::Errors", Module.new do
      const_set(:ERR_RISK_CONFIG_INVALID, "LOCAL")
    end)

    engine = described_class.new(account_collateral: {}, risk_config: {})

    expect do
      engine.pre_trade_check!(
        account_id: "acc-1",
        market_id: "ETH-USD",
        side: "SELL",
        quantity: "1",
        price: "100",
        position: position,
        accounting_method: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_AVERAGE
      )
    end.to raise_error(FCS::Error) { |e|
      expect(e.code).to eq(FCS::Errors::ERR_RISK_CONFIG_INVALID)
    }
  end

  it "raises when value is not Decimal18-compatible" do
    engine = described_class.new(account_collateral: {}, risk_config: {})

    expect { engine.send(:coerce_decimal18, 123) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_RISK_CONFIG_INVALID)
        expect(e.message).to eq("RiskEngine expects Decimal18-compatible values")
        expect(e.details).to eq(valueClass: "Integer")
      }
  end
end
