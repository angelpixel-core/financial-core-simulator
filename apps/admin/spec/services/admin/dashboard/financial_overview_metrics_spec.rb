require 'rails_helper'

RSpec.describe Admin::Dashboard::FinancialOverviewMetrics do
  describe '#call' do
    it 'filters trades missing required fields' do
      run = Run.create!(status: :succeeded, input_json: {
                          'trades' => [
                            { 'timestamp' => '2026-03-29T12:00:00Z', 'quantity' => 2, 'price' => 10,
                              'symbol' => 'BTC-USD' },
                            { 'timestamp' => '2026-03-29T12:00:00Z', 'quantity' => 1 }
                          ]
                        })

      metrics = described_class.new(run: run).call

      expect(metrics[:trade_activity].length).to eq(1)
      expect(metrics[:trade_activity].first).to include(timestamp: '2026-03-29', trade_count: 1)
    end

    it 'groups trade activity by normalized day' do
      run = Run.create!(status: :succeeded, input_json: {
                          'trades' => [
                            { 'timestamp' => '2026-03-29T12:00:00Z', 'quantity' => 2, 'price' => 10,
                              'symbol' => 'BTC-USD' },
                            { 'timestamp' => '2026-03-29T08:00:00-04:00', 'quantity' => 1, 'price' => 5,
                              'symbol' => 'BTC-USD' },
                            { 'timestamp' => '2026-03-29T13:00:00Z', 'quantity' => 1, 'price' => 5,
                              'symbol' => 'BTC-USD' }
                          ]
                        })

      metrics = described_class.new(run: run).call

      expect(metrics[:trade_activity]).to eq([
                                               { timestamp: '2026-03-29', trade_count: 3 }
                                             ])
    end

    it 'normalizes epoch timestamps and new field names' do
      run = Run.create!(status: :succeeded, input_json: {
                          'trades' => [
                            { 'timestamp' => 1_774_785_600, 'quantityBase' => 2, 'priceQuotePerBase' => 10,
                              'marketId' => 'BTC-USD' },
                            { 'timestamp' => '1774785600', 'quantityBase' => 1, 'priceQuotePerBase' => 5,
                              'marketId' => 'BTC-USD' }
                          ]
                        })

      metrics = described_class.new(run: run).call

      expect(metrics[:trade_activity]).to eq([
                                               { timestamp: '2026-03-29', trade_count: 2 }
                                             ])
      expect(metrics[:trade_volume]).to eq([
                                             {
                                               timestamp: '2026-03-29',
                                               volume: 25.0,
                                               unit_type: 'quote',
                                               unit_code: 'USD'
                                             }
                                           ])
    end

    it 'returns trade volume when unit resolution is consistent' do
      run = Run.create!(status: :succeeded, input_json: {
                          'trades' => [
                            { 'timestamp' => '2026-03-29T12:00:00Z', 'quantity' => 2, 'price' => 10,
                              'symbol' => 'BTC-USD' },
                            { 'timestamp' => '2026-03-29T12:00:00Z', 'quantity' => 1, 'price' => 5,
                              'symbol' => 'BTC-USD' }
                          ]
                        })

      metrics = described_class.new(run: run).call

      expect(metrics[:trade_volume]).to eq([
                                             {
                                               timestamp: '2026-03-29',
                                               volume: 25.0,
                                               unit_type: 'quote',
                                               unit_code: 'USD'
                                             }
                                           ])
    end

    it 'returns empty trade volume when units are inconsistent' do
      run = Run.create!(status: :succeeded, input_json: {
                          'trades' => [
                            { 'timestamp' => '2026-03-29T12:00:00Z', 'quantity' => 2, 'price' => 10,
                              'symbol' => 'BTC-USD' },
                            { 'timestamp' => '2026-03-29T12:05:00Z', 'quantity' => 1, 'price' => 5,
                              'symbol' => 'ETH-USD' },
                            { 'timestamp' => '2026-03-29T12:10:00Z', 'quantity' => 1, 'price' => 5,
                              'symbol' => 'BTC-EUR' }
                          ]
                        })

      metrics = described_class.new(run: run).call

      expect(metrics[:trade_volume]).to eq([])
      expect(metrics[:trade_activity].length).to eq(1)
      expect(metrics[:trade_activity].first).to include(timestamp: '2026-03-29', trade_count: 3)
    end
  end
end
