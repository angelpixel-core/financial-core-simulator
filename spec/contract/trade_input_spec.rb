# frozen_string_literal: true

require_relative '../../lib/fcs'

RSpec.describe FCS::Contracts::TradeInput do
  it 'builds a normalized trade hash' do
    trade = described_class.from_hash!(
      tradeId: 'trade-1',
      accountId: 'acc-1',
      marketId: 'ETH-USD',
      timestamp: 1_700_000_000,
      seq: 1,
      side: 'BUY',
      quantityBase: '1.5',
      priceQuotePerBase: '100.25',
      line: 2
    )

    expect(trade).to include(
      tradeId: 'trade-1',
      accountId: 'acc-1',
      marketId: 'ETH-USD',
      timestamp: 1_700_000_000,
      seq: 1,
      side: 'BUY',
      quantityBase: '1.5',
      priceQuotePerBase: '100.25',
      line: 2
    )
  end

  it 'raises when required fields are missing' do
    expect do
      described_class.from_hash!(
        tradeId: 'trade-1',
        accountId: 'acc-1'
      )
    end.to raise_error(ArgumentError, /Missing required fields/)
  end
end
