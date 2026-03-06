require "rails_helper"
require "json"
require "tmpdir"

RSpec.describe "Admin overview", type: :request do
  it "renders empty state without exploding when no runs exist" do
    get "/admin/overview", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Financial Overview")
    expect(response.body).to include("No succeeded runs yet.")
    expect(response.body).to include("Run trend (14d)")
    expect(response.body).to include("Status mix (30d)")
    expect(response.body).to include("data-controller=\"poll\"")
  end

  it "renders top accounts partial endpoint" do
    get "/admin/overview/top-accounts", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Top accounts (live)")
    expect(response.body).to include("Back to overview")
  end

  it "renders top accounts fragment for xhr polling" do
    get "/admin/overview/top-accounts", headers: admin_session_headers.merge("X-Requested-With" => "XMLHttpRequest")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Top accounts (live)")
    expect(response.body).not_to include("Back to overview")
  end

  it "returns forbidden when ADMIN_UI_TOKEN is set and token is missing" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/overview"

    expect(response).to have_http_status(:forbidden)
  end

  it "returns forbidden for top accounts endpoint when ADMIN_UI_TOKEN is set and token is missing" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/overview/top-accounts"

    expect(response).to have_http_status(:forbidden)
  end

  it "returns forbidden for top accounts xhr endpoint when ADMIN_UI_TOKEN is set and token is missing" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/overview/top-accounts", headers: { "X-Requested-With" => "XMLHttpRequest" }

    expect(response).to have_http_status(:forbidden)
  end

  it "denies unauthenticated access across overview and dashboard protected surfaces when ADMIN_UI_TOKEN is set" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    [
      "/admin/overview",
      "/admin/overview/top-accounts",
      "/dashboard/overview",
      "/dashboard/top-accounts",
      "/dashboard/ingestion-validation-errors"
    ].each do |path|
      get path, as: :json

      expect(response).to have_http_status(:forbidden), "Expected #{path} to require authentication"
    end
  end

  it "keeps admin html overview on session gate when ADMIN_UI_TOKEN is provided" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/overview", headers: { "X-Admin-Token" => "ui-secret" }

    expect(response).to have_http_status(:forbidden)
  end

  it "allows access via role-based policy when ADMIN_UI_TOKEN is set" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/overview", headers: { "X-Admin-User" => "alice", "X-Admin-Role" => "viewer" }

    expect(response).to have_http_status(:ok)
  end

  context "when live metrics source is available/unavailable" do
    it "prefers live metrics when live source is available" do
      Dir.mktmpdir do |dir|
        run_with_accounts_json(dir: dir, account_id: "acc-artifact", total_pnl_quote: "3.0")

        live_provider = class_double("Admin::LiveStateMetrics").as_stubbed_const
        live_instance = instance_double("Admin::LiveStateMetrics", call: live_metrics_for(account_id: "acc-live", total_pnl_quote: "77.0"))
        expect(live_provider).to receive(:new).and_return(live_instance)

        get "/admin/overview", headers: admin_session_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("acc-live")
        expect(response.body).not_to include("acc-artifact")
      end
    end

    it "falls back to artifact metrics when live source is unavailable" do
      Dir.mktmpdir do |dir|
        run_with_accounts_json(dir: dir, account_id: "acc-artifact", total_pnl_quote: "11.0")

        live_provider = class_double("Admin::LiveStateMetrics").as_stubbed_const
        live_instance = instance_double("Admin::LiveStateMetrics")
        expect(live_provider).to receive(:new).and_return(live_instance)
        expect(live_instance).to receive(:call).and_raise(StandardError, "live unavailable")

        get "/admin/overview", headers: admin_session_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("acc-artifact")
      end
    end
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

  def live_metrics_for(account_id:, total_pnl_quote:)
    {
      total_runs_7d: 0,
      total_runs_30d: 0,
      success_rate_last_50: 0,
      avg_duration_ms_last_50: nil,
      runs_trend_14d: (0...14).map { |offset| { day: (Date.current - (13 - offset)).strftime("%m-%d"), count: 0 } },
      status_mix_30d: { queued: 0, running: 0, succeeded: 0, failed: 0 },
      latest_run: nil,
      latest_global: nil,
      top_accounts: [
        {
          account_id: account_id,
          total_pnl_quote: BigDecimal(total_pnl_quote),
          realized_net_pnl_quote: BigDecimal(total_pnl_quote),
          unrealized_pnl_quote: BigDecimal("0.0")
        }
      ]
    }
  end

  def admin_session_headers
    { "X-Admin-User" => "alice", "X-Admin-Role" => "viewer" }
  end
end
