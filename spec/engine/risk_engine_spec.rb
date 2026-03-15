require_relative "../../lib/fcs"

RSpec.describe FCS::Engine::RiskEngine do
  let(:position) { FCS::Engine::Position.empty }

  it "rejects FIFO short selling" do
    engine = described_class.new(
      account_collateral: { "acc-1" => FCS::Types::Decimal18.from_string("100") },
      risk_config: { maxLeverage: FCS::Types::Decimal18.from_string("2") }
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
    end.to raise_error(FCS::Error) { |e| expect(e.code).to eq(FCS::Errors::ERR_RISK_CONFIG_INVALID) }
  end

  it "rejects trade when projected notional exceeds leverage limit" do
    engine = described_class.new(
      account_collateral: { "acc-1" => FCS::Types::Decimal18.from_string("100") },
      risk_config: { maxLeverage: FCS::Types::Decimal18.from_string("2") }
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
    end.to raise_error(FCS::Error) { |e| expect(e.code).to eq(FCS::Errors::ERR_RISK_REJECTION) }
  end

  it "returns deterministic liquidation candidates ordered by severity" do
    engine = described_class.new(
      account_collateral: {},
      risk_config: { maintenanceMarginRatio: FCS::Types::Decimal18.from_string("0.25") }
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
end
