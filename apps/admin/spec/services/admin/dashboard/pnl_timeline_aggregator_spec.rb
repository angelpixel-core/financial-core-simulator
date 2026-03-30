require 'rails_helper'

RSpec.describe Admin::Dashboard::PnlTimelineAggregator do
  describe '#call' do
    it 'returns the final point for each UTC date' do
      points = [
        {
          'timestamp' => '2026-03-29T12:00:00Z',
          'realized_pnl' => '1',
          'unrealized_pnl' => '2',
          'total_pnl' => '3'
        },
        {
          'timestamp' => '2026-03-29T23:59:00Z',
          'realized_pnl' => '2',
          'unrealized_pnl' => '3',
          'total_pnl' => '5'
        },
        {
          'timestamp' => '2026-03-30T00:01:00Z',
          'realized_pnl' => '4',
          'unrealized_pnl' => '1',
          'total_pnl' => '5'
        }
      ]

      result = described_class.new(points: points).call

      expect(result).to eq([
                             { timestamp: '2026-03-29', realized_pnl: 2.0, unrealized_pnl: 3.0, total_pnl: 5.0 },
                             { timestamp: '2026-03-30', realized_pnl: 4.0, unrealized_pnl: 1.0, total_pnl: 5.0 }
                           ])
    end
  end
end
