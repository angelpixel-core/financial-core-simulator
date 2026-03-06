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

  it "forbids Avo resources access when ADMIN_UI_TOKEN is set and missing" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/resources/runs"

    expect(response).to have_http_status(:forbidden)
  end

  it "allows Avo resources access when ADMIN_UI_TOKEN bearer token is provided" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/resources/runs", headers: { "Authorization" => "Bearer ui-secret" }

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
end
