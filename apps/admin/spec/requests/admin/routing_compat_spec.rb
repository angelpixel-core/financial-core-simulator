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
    expect(response.body).to include("Financial Core Simulator")
    expect(response.body).to include("View Demo")

    get "/admin/login"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sign in")
  end

  it "renders admin login page with authentication layout shell" do
    get "/admin/login"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("auth-shell")
    expect(response.body).to include("Sign in")
    expect(response.body).to include("Sign in to admin")
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

  it "allows Avo resources access when admin identity headers are provided" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/resources/runs", headers: { "X-Admin-User" => "alice", "X-Admin-Role" => "viewer" }

    expect(response).not_to have_http_status(:forbidden)
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

    post "/admin/login", params: { email: "ops@example.com", password: "secret-pass" }

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

    post "/admin/login", params: { email: "ops4@example.com", password: "secret-pass" }
    expect(response).to have_http_status(:found)

    get "/admin/overview/runs-trend"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-controller="run-trend-chart"')
    expect(response.body).to include('data-run-trend-chart-target="chart"')
    expect(response.body).to include('data-run-trend-chart-target="fallback"')
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

    post "/admin/login", params: { email: "ops2@example.com", password: "wrong-pass" }

    expect(response).not_to have_http_status(:ok)
    expect(response).not_to have_http_status(:found)
  end

  it "logs out admin session and redirects to login" do
    Account.create!(
      email: "ops3@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )

    post "/admin/login", params: { email: "ops3@example.com", password: "secret-pass" }
    expect(response).to have_http_status(:found)

    post "/admin/logout"

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
