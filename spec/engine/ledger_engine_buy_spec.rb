# frozen_string_literal: true

require_relative '../../lib/fcs'

RSpec.describe FCS::Engine::LedgerEngine do
  it 'applies SELL and accumulates realizedPnL using avg cost' do
    engine = described_class.new

    buy = {
      'tradeId' => 'b1',
      'accountId' => 'acc-1',
      'marketId' => 'ETH-USD',
      'timestamp' => 1,
      'seq' => 1,
      'side' => 'BUY',
      'quantityBase' => '3',
      'priceQuotePerBase' => '100'
    }

    sell = {
      'tradeId' => 's1',
      'accountId' => 'acc-1',
      'marketId' => 'ETH-USD',
      'timestamp' => 2,
      'seq' => 1,
      'side' => 'SELL',
      'quantityBase' => '2',
      'priceQuotePerBase' => '130'
    }

    engine.apply_trade!(buy)
    engine.apply_trade!(sell)

    pos = engine.state.position_for(account_id: 'acc-1', market_id: 'ETH-USD')

    expect(pos.qty.to_s).to eq('1.0')
    expect(pos.avg_cost.to_s).to eq('100.0')
    # realized = (130 - 100) * 2 = 60
    expect(pos.realized_pnl_quote.to_s).to eq('60.0')
  end

  it 'rejects SELL that would cross into short without risk configuration' do
    engine = described_class.new

    buy = {
      'tradeId' => 'b1',
      'accountId' => 'acc-1',
      'marketId' => 'ETH-USD',
      'timestamp' => 1,
      'seq' => 1,
      'side' => 'BUY',
      'quantityBase' => '1',
      'priceQuotePerBase' => '100'
    }

    sell = {
      'tradeId' => 's1',
      'accountId' => 'acc-1',
      'marketId' => 'ETH-USD',
      'timestamp' => 2,
      'seq' => 1,
      'side' => 'SELL',
      'quantityBase' => '2',
      'priceQuotePerBase' => '110'
    }

    engine.apply_trade!(buy)

    expect { engine.apply_trade!(sell) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_RISK_CONFIG_INVALID)
      }
  end

  it 'resets avg_cost to 0 when position is fully closed' do
    engine = described_class.new

    buy = {
      'tradeId' => 'b1',
      'accountId' => 'acc-1',
      'marketId' => 'ETH-USD',
      'timestamp' => 1,
      'seq' => 1,
      'side' => 'BUY',
      'quantityBase' => '2',
      'priceQuotePerBase' => '100'
    }

    sell = {
      'tradeId' => 's1',
      'accountId' => 'acc-1',
      'marketId' => 'ETH-USD',
      'timestamp' => 2,
      'seq' => 1,
      'side' => 'SELL',
      'quantityBase' => '2',
      'priceQuotePerBase' => '90'
    }

    engine.apply_trade!(buy)
    engine.apply_trade!(sell)

    pos = engine.state.position_for(account_id: 'acc-1', market_id: 'ETH-USD')
    expect(pos.qty.to_s).to eq('0.0')
    expect(pos.avg_cost.to_s).to eq('0.0')
  end
end
