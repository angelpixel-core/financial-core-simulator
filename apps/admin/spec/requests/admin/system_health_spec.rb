require "rails_helper"
require "json"
require "tmpdir"

RSpec.describe "Admin system health", type: :request do
  def admin_t(key, locale: I18n.locale)
    I18n.t("admin.#{key}", locale: locale)
  end

  it "renders system health for viewer session" do
    get "/admin/system-health", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(admin_t("nav.runs", locale: :en))
  end

  it "renders pnl trend empty state when no runs exist" do
    get "/admin/system-health", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(admin_t("overview.activity.pnl_trend.empty_title", locale: :en))
  end

  it "renders pnl trend chart hooks when successful runs include canonical pnl values" do
    run = Run.create!(
      status: :succeeded,
      valuation_timestamp: Time.zone.parse("2026-03-14T04:00:00Z"),
      input_json: { "schemaVersion" => "1.0" }
    )

    Dir.mktmpdir do |dir|
      path = File.join(dir, "result.json")
      File.write(path, JSON.pretty_generate({ "global" => { "totalPnLQuote" => "42.25" }, "accounts" => [] }))
      run.update!(artifacts: { "result_json_path" => path })

      get "/admin/system-health", headers: admin_session_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("data-controller=\"pnl-trend-chart\"")
      expect(response.body).to include("data-pnl-trend-chart-target=\"chart\"")
      expect(response.body).to include("<turbo-frame id=\"pnl_trend_fallback\"")
      expect(response.body).to include("data-pnl-trend-chart-tooltip-label-value=\"#{admin_t(
        "overview.activity.pnl_trend.tooltip", locale: :en
      )}\"")
      expect(response.body).to include(admin_t("overview.activity.pnl_trend.meta", locale: :en))
    end
  end

  def admin_session_headers
    { "X-Admin-User" => "alice", "X-Admin-Role" => "viewer" }
  end
end
