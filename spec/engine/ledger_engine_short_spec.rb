require_relative '../../lib/fcs'

RSpec.describe 'LedgerEngine short selling with leverage' do
  let(:collateral) { { 'acc-1' => FCS::Types::Decimal18.from_string('100') } }
  let(:max_leverage) { FCS::Types::Decimal18.from_string('2') }

  def sell_trade(qty:, price:, seq: 1)
    {
      'tradeId' => "s#{seq}",
      'accountId' => 'acc-1',
      'marketId' => 'ETH-USD',
      'timestamp' => seq,
      'seq' => seq,
      'side' => 'SELL',
      'quantityBase' => qty,
      'priceQuotePerBase' => price
    }
  end

  def buy_trade(qty:, price:, seq: 99)
    {
      'tradeId' => "b#{seq}",
      'accountId' => 'acc-1',
      'marketId' => 'ETH-USD',
      'timestamp' => seq,
      'seq' => seq,
      'side' => 'BUY',
      'quantityBase' => qty,
      'priceQuotePerBase' => price
    }
  end

  it 'allows short and cover within leverage limits' do
    engine = FCS::Engine::LedgerEngine.new(
      account_collateral: collateral,
      max_leverage: max_leverage
    )

    engine.apply_trade!(sell_trade(qty: '1', price: '100', seq: 1))
    engine.apply_trade!(buy_trade(qty: '1', price: '80', seq: 2))

    pos = engine.state.position_for(account_id: 'acc-1', market_id: 'ETH-USD')
    expect(pos.qty.to_s).to eq('0.0')
    expect(pos.realized_pnl_quote.to_s).to eq('20.0')
  end

  it 'rejects short when collateral or max leverage is missing' do
    engine = FCS::Engine::LedgerEngine.new

    expect { engine.apply_trade!(sell_trade(qty: '1', price: '100')) }
      .to raise_error(FCS::Error) { |e| expect(e.code).to eq(FCS::Errors::ERR_RISK_CONFIG_INVALID) }
  end

  it 'rejects short when leverage exceeds threshold' do
    engine = FCS::Engine::LedgerEngine.new(
      account_collateral: collateral,
      max_leverage: max_leverage
    )

    expect { engine.apply_trade!(sell_trade(qty: '3', price: '100')) }
      .to raise_error(FCS::Error) { |e| expect(e.code).to eq(FCS::Errors::ERR_RISK_REJECTION) }
  end
end
