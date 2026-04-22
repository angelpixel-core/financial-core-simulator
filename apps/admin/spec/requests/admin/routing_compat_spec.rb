require "rails_helper"
require "bcrypt"

RSpec.describe "Admin routing compatibility", type: :request do
  it "redirects legacy /avo root to /admin" do
    get "/avo"

    expect(response).to have_http_status(:moved_permanently)
    expect(response.headers["Location"]).to end_with("/admin")
  end

  it "redirects legacy /avo catch-all path to /admin equivalent" do
    get "/avo/resources/runs"

    expect(response).to have_http_status(:moved_permanently)
    expect(response.headers["Location"]).to end_with("/admin/resources/runs")
  end

  it "keeps exact /up publicly accessible even when ADMIN_UI_TOKEN is set" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/up"

    expect(response).to have_http_status(:ok)
  end

  it "does not treat non-exact /up/* paths as public health exceptions" do
    get "/up/internal"

    expect(response).not_to have_http_status(:ok)
  end

  it "renders a public landing at root and keeps login path explicit" do
    get "/"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Deterministic Financial Engine")
    expect(response.body).to include("View Demo")
    expect(response.body).not_to include("admin-shell-header")

    get "/admin/login"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("admin.auth.card.eyebrow", locale: :en))
  end

  it "renders admin login page with authentication layout shell" do
    get "/admin/login"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("auth-shell")
    expect(response.body).to include(I18n.t("admin.auth.card.eyebrow", locale: :en))
    expect(response.body).to include(I18n.t("admin.auth.form.submit", locale: :en))
  end

  it "redirects unauthenticated Avo resources access to root when ADMIN_UI_TOKEN is set" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/resources/runs"

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")
  end

  it "keeps unauthenticated Avo resources redirecting to public root even without ADMIN_UI_TOKEN" do
    get "/admin/resources/runs"

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")
  end

  it "forbids non-html unauthenticated Avo resources access when ADMIN_UI_TOKEN is set" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/resources/runs", as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it "denies Avo html resources when operator identity headers are provided" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/resources/runs", headers: {"X-Admin-User" => "ops", "X-Admin-Role" => "operator"}

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")
  end

  it "allows Avo resources access when admin identity headers are provided" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/resources/runs", headers: {"X-Admin-User" => "alice", "X-Admin-Role" => "admin"}

    expect(response).not_to have_http_status(:forbidden)
  end

  it "forbids non-html Avo resources for operator identity headers" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/resources/runs", as: :json, headers: {"X-Admin-User" => "ops", "X-Admin-Role" => "operator"}

    expect(response).to have_http_status(:forbidden)
  end

  it "forbids dashboard overview when ADMIN_UI_TOKEN is set and token is missing" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/dashboard/overview", as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it "creates session through admin login with valid credentials" do
    Account.create!(
      email: "ops@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )

    post "/admin/login", params: {email: "ops@example.com", password: "secret-pass"}

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/admin/overview")
    expect(response.headers["Set-Cookie"].to_s).to include("admin_session")

    get "/admin/overview"

    expect(response).to have_http_status(:ok)
  end

  it "renders trend detail with chart hook and fallback nodes under authenticated session" do
    Account.create!(
      email: "ops4@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )

    post "/admin/login", params: {email: "ops4@example.com", password: "secret-pass"}
    expect(response).to have_http_status(:found)

    get "/admin/overview/runs-trend"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-controller="run-trend-chart"')
    expect(response.body).to include('data-run-trend-chart-target="chart"')
    expect(response.body).to include('data-run-trend-chart-target="fallback"')
    expect(response.body).to include('data-run-trend-chart-chart-kind-value="bar"')
    expect(response.body).to include("data-run-trend-chart-tooltip-label-value=\"#{I18n.t("admin.common.day",
      locale: :en)}\"")
    expect(response.body).to include("data-run-trend-chart-tooltip-count-label-value=\"#{I18n.t("admin.common.runs",
      locale: :en)}\"")
    expect(response.body).to include('data-run-trend-chart-animation-mode-value="proportional"')
    expect(response.body).to include('data-run-trend-chart-base-duration-value="260"')
    expect(response.body).to include('data-run-trend-chart-max-extra-duration-value="540"')
  end

  it "rejects admin login with invalid credentials" do
    Account.create!(
      email: "ops2@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )

    post "/admin/login", params: {email: "ops2@example.com", password: "wrong-pass"}

    expect(response).not_to have_http_status(:ok)
    expect(response).not_to have_http_status(:found)
  end

  it "logs out admin session and redirects to login" do
    previous_enabled = ENV["DEMO_LOCK_ENABLED"]
    ENV["DEMO_LOCK_ENABLED"] = "1"

    Account.create!(
      email: "ops3@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )

    post "/admin/login", params: {email: "ops3@example.com", password: "secret-pass"}
    expect(response).to have_http_status(:found)

    account = Account.find_by(email: "ops3@example.com")
    Admin::Demo::Access.acquire(account_id: account.id, account_email: account.email)
    expect(Admin::Demo::Access.current_user).to include(account_id: account.id.to_s)

    post "/admin/logout"

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/admin/login")
    expect(Admin::Demo::Access.current_user).to be_nil

    get "/admin/overview"

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")
  ensure
    ENV["DEMO_LOCK_ENABLED"] = previous_enabled
  end

  it "does not expose a standalone logout page via GET" do
    Account.create!(
      email: "ops5@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )

    post "/admin/login", params: {email: "ops5@example.com", password: "secret-pass"}
    expect(response).to have_http_status(:found)

    get "/admin/logout"

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/admin/login")
  end

  it "redirects unauthenticated remember route access to admin login" do
    get "/admin/remember"

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/admin/login")
  end

  it "keeps remember route redirecting to admin login when ADMIN_UI_TOKEN is set" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/remember"

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/admin/login")
  end
end
