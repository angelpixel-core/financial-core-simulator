require 'rails_helper'

RSpec.describe 'Admin top accounts', type: :request do
  it 'renders accounts ordered by total pnl descending' do
    dashboard = instance_double(
      'Admin::DashboardMetrics',
      call: {
        top_accounts: [
          {
            account_id: 'acc-low',
            total_pnl_quote: BigDecimal('1.0'),
            realized_net_pnl_quote: BigDecimal('0.7'),
            unrealized_pnl_quote: BigDecimal('0.3')
          },
          {
            account_id: 'acc-high',
            total_pnl_quote: BigDecimal('10.0'),
            realized_net_pnl_quote: BigDecimal('6.0'),
            unrealized_pnl_quote: BigDecimal('4.0')
          }
        ]
      }
    )
    allow(Admin::DashboardMetrics).to receive(:new).and_return(dashboard)

    get '/admin/overview/top-accounts', headers: admin_session_headers.merge('X-Requested-With' => 'XMLHttpRequest')

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('aria-label="Top accounts actions"')
    expect(response.body).to include('table--striped')
    expect(response.body.index('acc-high')).to be < response.body.index('acc-low')
  end

  it 'renders empty-state text when top account data is missing' do
    dashboard = instance_double('Admin::DashboardMetrics', call: { top_accounts: nil })
    allow(Admin::DashboardMetrics).to receive(:new).and_return(dashboard)

    get '/admin/overview/top-accounts', headers: admin_session_headers.merge('X-Requested-With' => 'XMLHttpRequest')

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('No account totals available.')
    expect(response.body).not_to include('View top accounts')
    expect(response.body).to include('workspace-widget--empty')
  end

  it 'redirects standalone top accounts page to overview' do
    dashboard = instance_double('Admin::DashboardMetrics', call: { top_accounts: [] })
    allow(Admin::DashboardMetrics).to receive(:new).and_return(dashboard)

    get '/admin/overview/top-accounts', headers: admin_session_headers

    expect(response).to have_http_status(:found)
    expect(response.headers['Location']).to include('/admin/overview')
  end

  def admin_session_headers
    { 'X-Admin-User' => 'ops', 'X-Admin-Role' => 'operator' }
  end
end
