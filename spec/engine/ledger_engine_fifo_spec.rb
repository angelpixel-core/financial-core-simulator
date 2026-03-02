require_relative '../../lib/fcs'

RSpec.describe 'LedgerEngine FIFO accounting' do
  it 'realizes pnl using FIFO lots and keeps remaining lot avgCost' do
    engine = FCS::Engine::LedgerEngine.new(accounting_method: FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_FIFO)

    buy_1 = {
      'tradeId' => 'b1',
      'accountId' => 'acc-1',
      'marketId' => 'ETH-USD',
      'timestamp' => 1,
      'seq' => 1,
      'side' => 'BUY',
      'quantityBase' => '1',
      'priceQuotePerBase' => '100'
    }

    buy_2 = {
      'tradeId' => 'b2',
      'accountId' => 'acc-1',
      'marketId' => 'ETH-USD',
      'timestamp' => 2,
      'seq' => 2,
      'side' => 'BUY',
      'quantityBase' => '1',
      'priceQuotePerBase' => '120'
    }

    sell = {
      'tradeId' => 's1',
      'accountId' => 'acc-1',
      'marketId' => 'ETH-USD',
      'timestamp' => 3,
      'seq' => 3,
      'side' => 'SELL',
      'quantityBase' => '1',
      'priceQuotePerBase' => '130'
    }

    engine.apply_trade!(buy_1)
    engine.apply_trade!(buy_2)
    engine.apply_trade!(sell)

    pos = engine.state.position_for(account_id: 'acc-1', market_id: 'ETH-USD')

    expect(pos.qty.to_s).to eq('1.0')
    expect(pos.realized_pnl_quote.to_s).to eq('30.0')
    expect(pos.avg_cost.to_s).to eq('120.0')
  end
end
