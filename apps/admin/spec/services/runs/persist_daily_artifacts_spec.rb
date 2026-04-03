require 'rails_helper'
require 'json'
require 'tempfile'

RSpec.describe Runs::PersistDailyArtifacts do
  it 'persists daily artifacts idempotently' do
    temp = Tempfile.new(['result', '.json'])
    temp.write(JSON.generate(
                 {
                   'timeline' => {
                     'points' => [
                       {
                         'timestamp' => '2026-03-29T12:00:00Z',
                         'realized_pnl' => '1',
                         'unrealized_pnl' => '2',
                         'total_pnl' => '3'
                       },
                       {
                         'timestamp' => '2026-03-30T12:00:00Z',
                         'realized_pnl' => '2',
                         'unrealized_pnl' => '3',
                         'total_pnl' => '5'
                       }
                     ]
                   }
                 }
               ))
    temp.rewind

    input = {
      'trades' => [
        {
          'timestamp' => Time.utc(2026, 3, 29, 12, 0, 0).to_i,
          'quantityBase' => '2',
          'priceQuotePerBase' => '10',
          'marketId' => 'ETH-USD',
          'valid' => true
        },
        {
          'timestamp' => Time.utc(2026, 3, 30, 12, 0, 0).to_i,
          'quantityBase' => '1',
          'priceQuotePerBase' => '5',
          'marketId' => 'ETH-USD',
          'valid' => true
        }
      ],
      'timeline' => {
        'events' => [
          {
            'eventType' => 'TRADE_APPLIED',
            'timelineSeq' => 1,
            'timestamp' => '2026-03-29T12:00:00Z',
            'trade' => { 'valid' => true }
          },
          {
            'eventType' => 'TRADE_APPLIED',
            'timelineSeq' => 2,
            'timestamp' => '2026-03-30T12:00:00Z',
            'trade' => { 'valid' => true }
          }
        ]
      }
    }

    run = Run.create!(
      status: :succeeded,
      input_json: input,
      fx_context: {
        'reportingCurrency' => 'ARS',
        'rate' => '100',
        'rateMissing' => false
      },
      artifacts: { 'result_json_path' => temp.path }
    )

    described_class.call(run: run)
    described_class.call(run: run)

    expect(RunSnapshot.count).to eq(2)
    expect(RunDailyPnl.count).to eq(2)
    expect(RunDailyVolume.count).to eq(2)
    expect(RunDailyEvent.count).to eq(2)

    snapshot = RunSnapshot.find_by!(operational_date: Date.new(2026, 3, 29))
    volume = snapshot.run_daily_volume

    expect(volume.notional_volume.to_f).to eq(2000.0)
    expect(volume.trade_count).to eq(1)
    expect(volume.unit_code).to eq('ARS')
  ensure
    temp.close
    temp.unlink
  end
end
