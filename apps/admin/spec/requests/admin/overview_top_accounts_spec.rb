require "rails_helper"

RSpec.describe "Admin top accounts", type: :request do
  it "renders accounts ordered by total pnl descending" do
    dashboard = instance_double(
      "Admin::DashboardMetrics",
      call: {
        top_accounts: [
          {
            account_id: "acc-low",
            total_pnl_quote: BigDecimal("1.0"),
            realized_net_pnl_quote: BigDecimal("0.7"),
            unrealized_pnl_quote: BigDecimal("0.3")
          },
          {
            account_id: "acc-high",
            total_pnl_quote: BigDecimal("10.0"),
            realized_net_pnl_quote: BigDecimal("6.0"),
            unrealized_pnl_quote: BigDecimal("4.0")
          }
        ]
      }
    )
    allow(Admin::DashboardMetrics).to receive(:new).and_return(dashboard)

    get "/admin/overview/top-accounts", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body.index("acc-high")).to be < response.body.index("acc-low")
  end

  it "renders empty-state text when top account data is missing" do
    dashboard = instance_double("Admin::DashboardMetrics", call: { top_accounts: nil })
    allow(Admin::DashboardMetrics).to receive(:new).and_return(dashboard)

    get "/admin/overview/top-accounts", headers: admin_session_headers.merge("X-Requested-With" => "XMLHttpRequest")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No account totals available.")
    expect(response.body).to include("View top accounts")
  end

  it "does not render self drilldown CTA on standalone top accounts page" do
    dashboard = instance_double("Admin::DashboardMetrics", call: { top_accounts: [] })
    allow(Admin::DashboardMetrics).to receive(:new).and_return(dashboard)

    get "/admin/overview/top-accounts", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("View top accounts")
  end

  def admin_session_headers
    { "X-Admin-User" => "ops", "X-Admin-Role" => "operator" }
  end
end
