require 'rails_helper'
require 'json'
require 'tempfile'

RSpec.describe Admin::Dashboard::FinancialOverviewMetrics do
  describe '#call' do
    it 'prefers persisted artifacts when available' do
      run = Run.create!(status: :succeeded, input_json: { 'trades' => [] })

      snapshot = RunSnapshot.create!(
        run_id: run.id,
        operational_date: Date.new(2026, 3, 29),
        reporting_currency: 'USD'
      )

      RunDailyPnl.create!(
        run_snapshot_id: snapshot.id,
        realized_pnl: 1,
        unrealized_pnl: 2,
        total_pnl: 3
      )

      RunDailyVolume.create!(
        run_snapshot_id: snapshot.id,
        notional_volume: 25,
        trade_count: 4,
        unit_type: 'quote',
        unit_code: 'USD'
      )

      metrics = described_class.new(run: run).call

      expect(metrics[:trade_activity]).to eq([
                                               { timestamp: '2026-03-29', trade_count: 4 }
                                             ])
      expect(metrics[:trade_volume]).to eq([
                                             { timestamp: '2026-03-29', volume: 25.0, unit_type: 'quote',
                                               unit_code: 'USD' }
                                           ])
      expect(metrics[:pnl_daily]).to eq([
                                          { timestamp: '2026-03-29', realized_pnl: 1.0, unrealized_pnl: 2.0,
                                            total_pnl: 3.0 }
                                        ])
    end

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

    it 'scales trade volume using the FX rate when present' do
      FxDailyRate.create!(
        operational_date: Date.new(2026, 3, 29),
        base_currency: 'USD',
        quote_currency: 'ARS',
        rate: BigDecimal(100),
        source: 'manual'
      )

      run = Run.create!(
        status: :succeeded,
        input_json: {
          'trades' => [
            { 'timestamp' => '2026-03-29T12:00:00Z', 'quantity' => 2, 'price' => 10, 'symbol' => 'BTC-USD' },
            { 'timestamp' => '2026-03-29T12:00:00Z', 'quantity' => 1, 'price' => 5, 'symbol' => 'BTC-USD' }
          ]
        },
        fx_context: {
          'reportingCurrency' => 'ARS'
        }
      )

      metrics = described_class.new(run: run).call

      expect(metrics[:trade_volume]).to eq([
                                             {
                                               timestamp: '2026-03-29',
                                               volume: 2500.0,
                                               unit_type: 'quote',
                                               unit_code: 'ARS',
                                               fx_rate: '100.0',
                                               fx_rate_date: '2026-03-29',
                                               fx_missing: false
                                             }
                                           ])
    end

    it 'uses fxContext from input_json when run fx_context is missing' do
      FxDailyRate.create!(
        operational_date: Date.new(2026, 3, 29),
        base_currency: 'USD',
        quote_currency: 'ARS',
        rate: BigDecimal(100),
        source: 'manual'
      )

      run = Run.create!(
        status: :succeeded,
        input_json: {
          'trades' => [
            { 'timestamp' => '2026-03-29T12:00:00Z', 'quantity' => 2, 'price' => 10, 'symbol' => 'BTC-USD' },
            { 'timestamp' => '2026-03-29T12:00:00Z', 'quantity' => 1, 'price' => 5, 'symbol' => 'BTC-USD' }
          ],
          'fxContext' => {
            'reportingCurrency' => 'ARS'
          }
        }
      )

      metrics = described_class.new(run: run).call

      expect(metrics[:trade_volume]).to eq([
                                             {
                                               timestamp: '2026-03-29',
                                               volume: 2500.0,
                                               unit_type: 'quote',
                                               unit_code: 'ARS',
                                               fx_rate: '100.0',
                                               fx_rate_date: '2026-03-29',
                                               fx_missing: false
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

    it 'applies account and market filters across trades and pnl series' do
      temp = Tempfile.new(['result', '.json'])
      temp.write(JSON.generate(
                   {
                     'timeline' => {
                       'schema_version' => '1.0',
                       'points' => [
                         {
                           'timestamp' => '2026-03-29T12:00:00Z',
                           'account_id' => 'acc-1',
                           'market_id' => 'BTC-USD',
                           'realized_pnl' => '1',
                           'unrealized_pnl' => '2',
                           'total_pnl' => '3'
                         },
                         {
                           'timestamp' => '2026-03-29T13:00:00Z',
                           'account_id' => 'all',
                           'market_id' => 'BTC-USD',
                           'realized_pnl' => '0',
                           'unrealized_pnl' => '5',
                           'total_pnl' => '5'
                         },
                         {
                           'timestamp' => '2026-03-30T12:00:00Z',
                           'account_id' => 'acc-1',
                           'market_id' => 'BTC-USD',
                           'realized_pnl' => '2',
                           'unrealized_pnl' => '3',
                           'total_pnl' => '5'
                         },
                         {
                           'timestamp' => '2026-03-30T12:30:00Z',
                           'account_id' => 'acc-1',
                           'market_id' => 'ETH-USD',
                           'realized_pnl' => '2',
                           'unrealized_pnl' => '1',
                           'total_pnl' => '3'
                         }
                       ]
                     }
                   }
                 ))
      temp.rewind

      run = Run.create!(status: :succeeded,
                        input_json: {
                          'trades' => [
                            { 'timestamp' => '2026-03-29T12:00:00Z', 'quantity' => 2, 'price' => 10,
                              'symbol' => 'BTC-USD', 'accountId' => 'acc-1', 'marketId' => 'BTC-USD' },
                            { 'timestamp' => '2026-03-29T12:00:00Z', 'quantity' => 1, 'price' => 5,
                              'symbol' => 'BTC-USD', 'accountId' => 'acc-2', 'marketId' => 'BTC-USD' }
                          ]
                        },
                        artifacts: { 'result_json_path' => temp.path })

      metrics = described_class.new(run: run, account_id: 'acc-1', market_id: 'BTC-USD').call

      expect(metrics[:trade_activity]).to eq([
                                               { timestamp: '2026-03-29', trade_count: 1 }
                                             ])
      expect(metrics[:trade_volume]).to eq([
                                             {
                                               timestamp: '2026-03-29',
                                               volume: 20.0,
                                               unit_type: 'quote',
                                               unit_code: 'USD'
                                             }
                                           ])
      expect(metrics[:pnl_daily]).to eq([
                                          { timestamp: '2026-03-29', realized_pnl: 1.0, unrealized_pnl: 2.0,
                                            total_pnl: 3.0 },
                                          { timestamp: '2026-03-30', realized_pnl: 2.0, unrealized_pnl: 3.0,
                                            total_pnl: 5.0 }
                                        ])
    ensure
      temp.close
      temp.unlink
    end

    it 'includes price updates only when unfiltered' do
      temp = Tempfile.new(['result', '.json'])
      temp.write(JSON.generate(
                   {
                     'timeline' => {
                       'schema_version' => '1.0',
                       'points' => [
                         {
                           'timestamp' => '2026-03-29T12:00:00Z',
                           'account_id' => 'acc-1',
                           'market_id' => 'BTC-USD',
                           'realized_pnl' => '1',
                           'unrealized_pnl' => '2',
                           'total_pnl' => '3'
                         },
                         {
                           'timestamp' => '2026-03-29T13:00:00Z',
                           'account_id' => 'all',
                           'market_id' => 'BTC-USD',
                           'realized_pnl' => '0',
                           'unrealized_pnl' => '5',
                           'total_pnl' => '5'
                         }
                       ]
                     }
                   }
                 ))
      temp.rewind

      run = Run.create!(status: :succeeded, input_json: { 'trades' => [] },
                        artifacts: { 'result_json_path' => temp.path })

      unfiltered = described_class.new(run: run).call
      filtered = described_class.new(run: run, account_id: 'acc-1').call

      expect(unfiltered[:pnl_daily]).to eq([
                                             { timestamp: '2026-03-29', realized_pnl: 0.0, unrealized_pnl: 5.0,
                                               total_pnl: 5.0 }
                                           ])
      expect(filtered[:pnl_daily]).to eq([
                                           { timestamp: '2026-03-29', realized_pnl: 1.0, unrealized_pnl: 2.0,
                                             total_pnl: 3.0 }
                                         ])
    ensure
      temp.close
      temp.unlink
    end

    it 'scales pnl daily values using the FX rate when present' do
      FxDailyRate.create!(
        operational_date: Date.new(2026, 3, 29),
        base_currency: 'USD',
        quote_currency: 'ARS',
        rate: BigDecimal(150),
        source: 'manual'
      )

      temp = Tempfile.new(['result', '.json'])
      temp.write(JSON.generate(
                   {
                     'timeline' => {
                       'schema_version' => '1.0',
                       'points' => [
                         {
                           'timestamp' => '2026-03-29T12:00:00Z',
                           'realized_pnl' => '1',
                           'unrealized_pnl' => '2',
                           'total_pnl' => '3'
                         }
                       ]
                     }
                   }
                 ))
      temp.rewind

      run = Run.create!(
        status: :succeeded,
        input_json: { 'trades' => [] },
        artifacts: { 'result_json_path' => temp.path },
        fx_context: {
          'reportingCurrency' => 'ARS'
        }
      )

      metrics = described_class.new(run: run).call

      expect(metrics[:pnl_daily]).to eq([
                                          {
                                            timestamp: '2026-03-29',
                                            realized_pnl: 150.0,
                                            unrealized_pnl: 300.0,
                                            total_pnl: 450.0,
                                            fx_rate: '150.0',
                                            fx_rate_date: '2026-03-29',
                                            fx_missing: false
                                          }
                                        ])
    ensure
      temp.close
      temp.unlink
    end

    it 'keeps USD values when the daily FX rate is missing' do
      FxRateGap.create!(
        operational_date: Date.new(2026, 3, 29),
        base_currency: 'USD',
        quote_currency: 'ARS',
        status: 'open'
      )

      temp = Tempfile.new(['result', '.json'])
      temp.write(JSON.generate(
                   {
                     'timeline' => {
                       'schema_version' => '1.0',
                       'points' => [
                         {
                           'timestamp' => '2026-03-29T12:00:00Z',
                           'realized_pnl' => '1',
                           'unrealized_pnl' => '2',
                           'total_pnl' => '3'
                         }
                       ]
                     }
                   }
                 ))
      temp.rewind

      run = Run.create!(
        status: :succeeded,
        input_json: {
          'trades' => [
            { 'timestamp' => '2026-03-29T12:00:00Z', 'quantity' => 2, 'price' => 10, 'symbol' => 'BTC-USD' },
            { 'timestamp' => '2026-03-29T12:00:00Z', 'quantity' => 1, 'price' => 5, 'symbol' => 'BTC-USD' }
          ]
        },
        artifacts: { 'result_json_path' => temp.path },
        fx_context: {
          'reportingCurrency' => 'ARS'
        }
      )

      metrics = described_class.new(run: run).call

      expect(metrics[:trade_volume]).to eq([
                                             {
                                               timestamp: '2026-03-29',
                                               volume: 25.0,
                                               unit_type: 'quote',
                                               unit_code: 'USD',
                                               fx_rate: nil,
                                               fx_rate_date: '2026-03-29',
                                               fx_missing: true
                                             }
                                           ])
      expect(metrics[:pnl_daily]).to eq([
                                          {
                                            timestamp: '2026-03-29',
                                            realized_pnl: 1.0,
                                            unrealized_pnl: 2.0,
                                            total_pnl: 3.0,
                                            fx_rate: nil,
                                            fx_rate_date: '2026-03-29',
                                            fx_missing: true
                                          }
                                        ])
    ensure
      temp.close
      temp.unlink
    end

    it 'does not apply per-day FX when reporting currency is USD' do
      temp = Tempfile.new(['result', '.json'])
      temp.write(JSON.generate(
                   {
                     'timeline' => {
                       'schema_version' => '1.0',
                       'points' => [
                         {
                           'timestamp' => '2026-03-29T12:00:00Z',
                           'realized_pnl' => '1',
                           'unrealized_pnl' => '2',
                           'total_pnl' => '3'
                         }
                       ]
                     }
                   }
                 ))
      temp.rewind

      run = Run.create!(
        status: :succeeded,
        input_json: {
          'trades' => [
            { 'timestamp' => '2026-03-29T12:00:00Z', 'quantity' => 2, 'price' => 10, 'symbol' => 'BTC-USD' }
          ]
        },
        artifacts: { 'result_json_path' => temp.path },
        fx_context: {
          'reportingCurrency' => 'USD'
        }
      )

      metrics = described_class.new(run: run).call

      expect(metrics[:trade_volume]).to eq([
                                             {
                                               timestamp: '2026-03-29',
                                               volume: 20.0,
                                               unit_type: 'quote',
                                               unit_code: 'USD'
                                             }
                                           ])
      expect(metrics[:pnl_daily]).to eq([
                                          { timestamp: '2026-03-29', realized_pnl: 1.0, unrealized_pnl: 2.0,
                                            total_pnl: 3.0 }
                                        ])
    ensure
      temp.close
      temp.unlink
    end

    it 'batches FX availability lookups for daily conversion' do
      FxDailyRate.create!(
        operational_date: Date.new(2026, 3, 29),
        base_currency: 'USD',
        quote_currency: 'ARS',
        rate: BigDecimal(100),
        source: 'manual'
      )
      FxDailyRate.create!(
        operational_date: Date.new(2026, 3, 30),
        base_currency: 'USD',
        quote_currency: 'ARS',
        rate: BigDecimal(110),
        source: 'manual'
      )

      run = Run.create!(
        status: :succeeded,
        input_json: {
          'trades' => [
            { 'timestamp' => '2026-03-29T12:00:00Z', 'quantity' => 1, 'price' => 10, 'symbol' => 'BTC-USD' },
            { 'timestamp' => '2026-03-30T12:00:00Z', 'quantity' => 1, 'price' => 10, 'symbol' => 'BTC-USD' }
          ]
        },
        fx_context: {
          'reportingCurrency' => 'ARS'
        }
      )

      expect(FxDailyRate).to receive(:where).once.and_call_original
      expect(FxRateGap).to receive(:open_status).once.and_call_original

      described_class.new(run: run).call
    end
  end
end
