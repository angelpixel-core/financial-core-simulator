require 'rails_helper'
require 'json'
require 'tmpdir'

RSpec.describe 'Admin overview BFF feature flag', type: :request do
  it 'uses BFF read path when ADMIN_DASHBOARD_BFF_READ_ENABLED is on' do
    Dir.mktmpdir do |dir|
      run_with_accounts_json(dir: dir, account_id: 'acc-artifact', total_pnl_quote: '3.0')

      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('ADMIN_DASHBOARD_BFF_READ_ENABLED').and_return('1')

      stub_const('Admin::Dashboard::BffReadMetrics', Class.new)
      bff_instance = instance_double('Admin::Dashboard::BffReadMetrics', call: bff_metrics_for(account_id: 'acc-bff'))
      allow(Admin::Dashboard::BffReadMetrics).to receive(:new).and_return(bff_instance)

      get '/admin/overview', headers: admin_session_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('acc-bff')
      expect(response.body).to include('77.0')
      expect(response.body).not_to include('acc-artifact')
    end
  end

  it 'keeps artifact-native read path when ADMIN_DASHBOARD_BFF_READ_ENABLED is off' do
    Dir.mktmpdir do |dir|
      run_with_accounts_json(dir: dir, account_id: 'acc-artifact', total_pnl_quote: '11.0')

      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('ADMIN_DASHBOARD_BFF_READ_ENABLED').and_return('0')

      get '/admin/overview', headers: admin_session_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('acc-artifact')
    end
  end

  def run_with_accounts_json(dir:, account_id:, total_pnl_quote:)
    run = Run.create!(status: :succeeded, input_json: { 'schemaVersion' => '1.0' })
    path = File.join(dir, 'result.json')
    File.write(path, JSON.pretty_generate(result_payload(account_id: account_id, total_pnl_quote: total_pnl_quote)))
    run.update!(artifacts: { 'result_json_path' => path })
    run
  end

  def result_payload(account_id:, total_pnl_quote:)
    {
      'global' => {
        'totalPnLQuote' => total_pnl_quote,
        'realizedNetPnLQuote' => total_pnl_quote,
        'unrealizedPnLQuote' => '0.0',
        'totalPnLUsd' => total_pnl_quote
      },
      'accounts' => [
        {
          'accountId' => account_id,
          'totals' => {
            'totalPnLQuote' => total_pnl_quote,
            'realizedNetPnLQuote' => total_pnl_quote,
            'unrealizedPnLQuote' => '0.0'
          }
        }
      ]
    }
  end

  def bff_metrics_for(account_id:)
    {
      total_runs_7d: 0,
      total_runs_30d: 0,
      success_rate_last_50: 0,
      avg_duration_ms_last_50: nil,
      runs_trend_14d: (0...14).map { |offset| { day: (Date.current - (13 - offset)).strftime('%m-%d'), count: 0 } },
      status_mix_30d: { queued: 0, running: 0, succeeded: 0, failed: 0 },
      latest_run: nil,
      latest_global: {
        'totalPnLQuote' => '777.0',
        'realizedNetPnLQuote' => '700.0',
        'unrealizedPnLQuote' => '77.0',
        'totalPnLUsd' => '777.0'
      },
      top_accounts: [
        {
          account_id: account_id,
          total_pnl_quote: BigDecimal('77.0'),
          realized_net_pnl_quote: BigDecimal('70.0'),
          unrealized_pnl_quote: BigDecimal('7.0')
        }
      ]
    }
  end

  def admin_session_headers
    { 'X-Admin-User' => 'ops', 'X-Admin-Role' => 'operator' }
  end
end
