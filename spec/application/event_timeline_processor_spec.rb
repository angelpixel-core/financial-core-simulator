# frozen_string_literal: true

require_relative '../../lib/fcs'

RSpec.describe FCS::Application::EventTimelineProcessor do
  def d18(value)
    FCS::Types::Decimal18.from_string(value)
  end

  it 'processes events in timeline order and writes checkpoints' do
    ledger_state = instance_spy('LedgerState', positions: {})
    ledger = instance_spy('Ledger', state: ledger_state)
    valuation = instance_spy('Valuation')
    checkpoint_store = instance_spy('CheckpointStore')
    position = instance_spy('Position', realized_pnl_quote: d18('5'), realized_net_quote: d18('4'))

    allow(ledger_state).to receive(:position_for).and_return(position)
    allow(valuation).to receive(:unrealized_pnl_quote).and_return(d18('1'))

    events = [
      {
        'eventType' => 'TRADE_APPLIED',
        'timelineSeq' => 2,
        'timestamp' => '2026-03-29T12:05:00Z',
        'trade' => {
          'tradeId' => 't-1',
          'accountId' => 'acc-1',
          'marketId' => 'ETH-USD',
          'seq' => 1,
          'side' => 'BUY',
          'quantityBase' => '1',
          'priceQuotePerBase' => '100'
        }
      },
      {
        'eventType' => 'PRICE_UPDATED',
        'timelineSeq' => 1,
        'timestamp' => '2026-03-29T12:00:00Z',
        'marketId' => 'ETH-USD',
        'priceQuotePerBase' => '110'
      }
    ]

    timeline_points = described_class.new.call(
      events: events,
      ledger: ledger,
      valuation: valuation,
      checkpoint_store: checkpoint_store,
      input_hash: 'hash-1'
    )

    expect(valuation).to have_received(:update_price!).with(
      market_id: 'ETH-USD',
      price_quote_per_base: '110'
    )
    expect(ledger).to have_received(:apply_trade!).with(
      'tradeId' => 't-1',
      'accountId' => 'acc-1',
      'marketId' => 'ETH-USD',
      'seq' => 1,
      'side' => 'BUY',
      'quantityBase' => '1',
      'priceQuotePerBase' => '100'
    )
    expect(checkpoint_store).to have_received(:write_if_due!).with(
      event_count: 1,
      timeline_seq: 1,
      state: { 'accounts' => [] },
      input_hash: 'hash-1'
    )
    expect(checkpoint_store).to have_received(:write_if_due!).with(
      event_count: 2,
      timeline_seq: 2,
      state: { 'accounts' => [] },
      input_hash: 'hash-1'
    )
    expect(timeline_points).to eq([
                                    {
                                      'timestamp' => '2026-03-29T12:00:00Z',
                                      'account_id' => 'all',
                                      'market_id' => 'ETH-USD',
                                      'realized_pnl' => '0.0',
                                      'unrealized_pnl' => '0.0',
                                      'total_pnl' => '0.0'
                                    },
                                    {
                                      'timestamp' => '2026-03-29T12:05:00Z',
                                      'account_id' => 'acc-1',
                                      'market_id' => 'ETH-USD',
                                      'realized_pnl' => '5.0',
                                      'unrealized_pnl' => '1.0',
                                      'total_pnl' => '5.0'
                                    }
                                  ])
  end

  it 'skips events at or before checkpoint sequence' do
    position = instance_spy('Position')
    ledger_state = instance_spy('LedgerState', positions: {})
    allow(ledger_state).to receive(:position_for)
      .with(account_id: 'acc-1', market_id: 'ETH-USD')
      .and_return(position)

    ledger = instance_spy('Ledger', state: ledger_state)
    valuation = instance_spy('Valuation')

    checkpoint = {
      'timelineSeq' => 2,
      'state' => {
        'accounts' => [
          {
            'accountId' => 'acc-1',
            'markets' => [
              { 'marketId' => 'ETH-USD', 'quantity' => '1', 'avgCost' => '100' }
            ]
          }
        ]
      }
    }

    events = [
      { 'eventType' => 'TRADE_APPLIED', 'timelineSeq' => 1, 'timestamp' => '2026-03-29T12:00:00Z', 'trade' => {} },
      { 'eventType' => 'TRADE_APPLIED', 'timelineSeq' => 2, 'timestamp' => '2026-03-29T12:01:00Z', 'trade' => {} },
      { 'eventType' => 'PRICE_UPDATED', 'timelineSeq' => 3, 'timestamp' => '2026-03-29T12:02:00Z', 'marketId' => 'ETH-USD',
        'priceQuotePerBase' => '120' }
    ]

    timeline_points = described_class.new.call(
      events: events,
      ledger: ledger,
      valuation: valuation,
      checkpoint: checkpoint
    )

    expect(position).to have_received(:apply_buy!).with(
      buy_qty: have_attributes(atoms: d18('1').atoms),
      buy_price: have_attributes(atoms: d18('100').atoms)
    )
    expect(valuation).to have_received(:update_price!).with(market_id: 'ETH-USD', price_quote_per_base: '120')
    expect(ledger).not_to have_received(:apply_trade!)
    expect(timeline_points).to eq([
                                    {
                                      'timestamp' => '2026-03-29T12:02:00Z',
                                      'account_id' => 'all',
                                      'market_id' => 'ETH-USD',
                                      'realized_pnl' => '0.0',
                                      'unrealized_pnl' => '0.0',
                                      'total_pnl' => '0.0'
                                    }
                                  ])
  end

  it 'captures sorted account and market positions for checkpoints' do
    positions = {
      'acc-2|ETH-USD' => instance_spy('Position', qty: d18('1'), avg_cost: d18('100'), realized_pnl_quote: d18('0'),
                                                  realized_net_quote: d18('0')),
      'acc-1|BTC-USD' => instance_spy('Position', qty: d18('2'), avg_cost: d18('90'), realized_pnl_quote: d18('0'),
                                                  realized_net_quote: d18('0')),
      'acc-1|ETH-USD' => instance_spy('Position', qty: d18('3'), avg_cost: d18('80'), realized_pnl_quote: d18('0'),
                                                  realized_net_quote: d18('0'))
    }

    ledger_state = instance_spy('LedgerState', positions: positions)
    ledger = instance_spy('Ledger', state: ledger_state)
    valuation = instance_spy('Valuation')
    checkpoint_store = instance_spy('CheckpointStore')
    allow(valuation).to receive(:unrealized_pnl_quote).and_return(d18('0'))

    timeline_points = described_class.new.call(
      events: [
        { 'eventType' => 'PRICE_UPDATED', 'timelineSeq' => 1, 'timestamp' => '2026-03-29T12:00:00Z',
          'marketId' => 'ETH-USD', 'priceQuotePerBase' => '110' }
      ],
      ledger: ledger,
      valuation: valuation,
      checkpoint_store: checkpoint_store
    )

    expect(valuation).to have_received(:update_price!).with(market_id: 'ETH-USD', price_quote_per_base: '110')
    expect(checkpoint_store).to have_received(:write_if_due!).with(
      event_count: 1,
      timeline_seq: 1,
      state: {
        'accounts' => [
          {
            'accountId' => 'acc-1',
            'markets' => [
              { 'marketId' => 'BTC-USD', 'quantity' => '2.0', 'avgCost' => '90.0' },
              { 'marketId' => 'ETH-USD', 'quantity' => '3.0', 'avgCost' => '80.0' }
            ]
          },
          {
            'accountId' => 'acc-2',
            'markets' => [
              { 'marketId' => 'ETH-USD', 'quantity' => '1.0', 'avgCost' => '100.0' }
            ]
          }
        ]
      },
      input_hash: ''
    )
    expect(timeline_points).to eq([
                                    {
                                      'timestamp' => '2026-03-29T12:00:00Z',
                                      'account_id' => 'all',
                                      'market_id' => 'ETH-USD',
                                      'realized_pnl' => '0.0',
                                      'unrealized_pnl' => '0.0',
                                      'total_pnl' => '0.0'
                                    }
                                  ])
  end
end
