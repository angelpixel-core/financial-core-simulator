require 'rails_helper'
require 'json'
require 'tempfile'

RSpec.describe 'Dashboard financial overview', type: :request do
  it 'returns financial overview payload for valid run' do
    run = Run.create!(status: :succeeded, input_json: {
                        'trades' => [
                          { 'timestamp' => '2026-03-29T12:00:00Z', 'quantity' => 2, 'price' => 10, 'symbol' => 'BTC-USD' }
                        ]
                      })

    get "/dashboard/financial-overview/#{run.id}", as: :json

    expect(response).to have_http_status(:ok)

    parsed = JSON.parse(response.body)
    expect(parsed.fetch('contractVersion')).to eq('v1')
    overview = parsed.fetch('financial_overview')
    expect(overview.fetch('trade_activity')).to be_a(Array)
    expect(overview.fetch('trade_volume')).to be_a(Array)
    expect(overview.fetch('pnlDaily')).to be_a(Array)
  end

  it 'applies account and market filters with pnlDaily' do
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
                         'account_id' => 'acc-2',
                         'market_id' => 'BTC-USD',
                         'realized_pnl' => '3',
                         'unrealized_pnl' => '1',
                         'total_pnl' => '4'
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
                            'symbol' => 'BTC-USD', 'accountId' => 'acc-1', 'marketId' => 'BTC-USD' }
                        ]
                      },
                      artifacts: { 'result_json_path' => temp.path })

    get "/dashboard/financial-overview/#{run.id}?account_id=acc-1&market_id=BTC-USD", as: :json

    expect(response).to have_http_status(:ok)
    parsed = JSON.parse(response.body)
    overview = parsed.fetch('financial_overview')
    expect(overview.fetch('pnlDaily')).to eq([
                                               { 'timestamp' => '2026-03-29', 'realized_pnl' => 1.0,
                                                 'unrealized_pnl' => 2.0, 'total_pnl' => 3.0 }
                                             ])
  ensure
    temp.close
    temp.unlink
  end

  it 'returns not found for missing run' do
    get '/dashboard/financial-overview/999999', as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'includes FX metadata for non-USD reporting currency' do
    FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 29),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: BigDecimal(100),
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
      input_json: {
        'trades' => [
          { 'timestamp' => '2026-03-29T12:00:00Z', 'quantity' => 2, 'price' => 10, 'symbol' => 'BTC-USD' }
        ]
      },
      artifacts: { 'result_json_path' => temp.path },
      fx_context: { 'reportingCurrency' => 'ARS' }
    )

    get "/dashboard/financial-overview/#{run.id}", as: :json

    expect(response).to have_http_status(:ok)
    parsed = JSON.parse(response.body)
    overview = parsed.fetch('financial_overview')

    expect(overview.fetch('trade_volume').first).to include('fx_rate', 'fx_rate_date', 'fx_missing')
    expect(overview.fetch('pnlDaily').first).to include('fx_rate', 'fx_rate_date', 'fx_missing')
  ensure
    temp.close
    temp.unlink
  end

  it 'filters aggregated metrics by selected run filenames' do
    first_run = Run.create!(status: :succeeded, input_json: { 'trades' => [] })
    second_run = Run.create!(status: :succeeded, input_json: { 'trades' => [] })

    first_snapshot = RunSnapshot.create!(
      run: first_run,
      operational_date: Date.new(2026, 3, 29),
      reporting_currency: 'USD'
    )
    second_snapshot = RunSnapshot.create!(
      run: second_run,
      operational_date: Date.new(2026, 3, 30),
      reporting_currency: 'USD'
    )

    RunDailyVolume.create!(run_snapshot: first_snapshot, notional_volume: 10, trade_count: 2, unit_type: 'quote',
                           unit_code: 'USD')
    RunDailyPnl.create!(run_snapshot: first_snapshot, realized_pnl: 1, unrealized_pnl: 0, total_pnl: 1)
    RunDailyVolume.create!(run_snapshot: second_snapshot, notional_volume: 30, trade_count: 5, unit_type: 'quote',
                           unit_code: 'USD')
    RunDailyPnl.create!(run_snapshot: second_snapshot, realized_pnl: 2, unrealized_pnl: 0, total_pnl: 2)

    DemoDatasetUpload.create!(status: :valid, run_id: first_run.id, original_filename: 'alpha_20260416.xlsx')
    DemoDatasetUpload.create!(status: :valid, run_id: second_run.id, original_filename: 'beta_20260417.xlsx')

    get "/dashboard/financial-overview/#{first_run.id}", params: { run_filenames: ['beta_20260417.xlsx'] }, as: :json

    expect(response).to have_http_status(:ok)
    parsed = JSON.parse(response.body)
    overview = parsed.fetch('financial_overview')

    expect(overview.fetch('trade_activity')).to eq([
                                                     { 'timestamp' => '2026-03-30', 'trade_count' => 5 }
                                                   ])
  end
end
