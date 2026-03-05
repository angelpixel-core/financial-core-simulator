require "rails_helper"
require "json"
require "tmpdir"

RSpec.describe "Admin overview BFF fallback", type: :request do
  it "falls back to artifact-native metrics when BFF read degrades and fallback is enabled" do
    Dir.mktmpdir do |dir|
      run_with_accounts_json(dir: dir, account_id: "acc-fallback-artifact", total_pnl_quote: "15.0")

      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("ADMIN_DASHBOARD_BFF_READ_ENABLED").and_return("1")
      allow(ENV).to receive(:[]).with("ADMIN_DASHBOARD_BFF_FALLBACK_ENABLED").and_return("1")

      failing_bff = instance_double("Admin::Dashboard::BffReadMetrics")
      allow(failing_bff).to receive(:call).and_raise(StandardError, "bff unavailable")
      allow(Admin::Dashboard::BffReadMetrics).to receive(:new).and_return(failing_bff)

      get "/admin/overview"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("acc-fallback-artifact")
    end
  end

  it "keeps dashboard widget endpoint available on BFF degradation when fallback is enabled" do
    Dir.mktmpdir do |dir|
      run_with_accounts_json(dir: dir, account_id: "acc-fallback-artifact", total_pnl_quote: "15.0")

      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("ADMIN_DASHBOARD_BFF_READ_ENABLED").and_return("1")
      allow(ENV).to receive(:[]).with("ADMIN_DASHBOARD_BFF_FALLBACK_ENABLED").and_return("1")

      failing_bff = instance_double("Admin::Dashboard::BffReadMetrics")
      allow(failing_bff).to receive(:call).and_raise(StandardError, "bff unavailable")
      allow(Admin::Dashboard::BffReadMetrics).to receive(:new).and_return(failing_bff)

      get "/dashboard/top-accounts", as: :json

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("acc-fallback-artifact")
    end
  end

  it "returns non-success for dashboard widget endpoint on BFF degradation when fallback is disabled" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_DASHBOARD_BFF_READ_ENABLED").and_return("1")
    allow(ENV).to receive(:[]).with("ADMIN_DASHBOARD_BFF_FALLBACK_ENABLED").and_return("0")

    failing_bff = instance_double("Admin::Dashboard::BffReadMetrics")
    allow(failing_bff).to receive(:call).and_raise(StandardError, "bff unavailable")
    allow(Admin::Dashboard::BffReadMetrics).to receive(:new).and_return(failing_bff)

    get "/dashboard/top-accounts", as: :json

    expect(response).to have_http_status(:internal_server_error)
  end

  def run_with_accounts_json(dir:, account_id:, total_pnl_quote:)
    run = Run.create!(status: :succeeded, input_json: { "schemaVersion" => "1.0" })
    path = File.join(dir, "result.json")
    File.write(path, JSON.pretty_generate(result_payload(account_id: account_id, total_pnl_quote: total_pnl_quote)))
    run.update!(artifacts: { "result_json_path" => path })
    run
  end

  def result_payload(account_id:, total_pnl_quote:)
    {
      "global" => {
        "totalPnLQuote" => total_pnl_quote,
        "realizedNetPnLQuote" => total_pnl_quote,
        "unrealizedPnLQuote" => "0.0",
        "totalPnLUsd" => total_pnl_quote
      },
      "accounts" => [
        {
          "accountId" => account_id,
          "totals" => {
            "totalPnLQuote" => total_pnl_quote,
            "realizedNetPnLQuote" => total_pnl_quote,
            "unrealizedPnLQuote" => "0.0"
          }
        }
      ]
    }
  end
end
