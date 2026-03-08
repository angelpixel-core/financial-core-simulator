require "rails_helper"
require "bcrypt"

RSpec.describe "Admin component comparison", type: :request do
  it "renders both ViewComponent and Phlex cards" do
    get "/admin/component-comparison", headers: { "X-Admin-User" => "alice", "X-Admin-Role" => "viewer" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Component Comparison: ViewComponent vs Phlex")
    expect(response.body).to include("ViewComponent")
    expect(response.body).to include("Phlex")
    expect(response.body).to include("Success rate (last 50)")
  end

  it "renders shared shell identity and logout affordance on non-overview admin page" do
    Account.create!(
      email: "ops-component@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )

    post "/admin/login", params: { email: "ops-component@example.com", password: "secret-pass" }
    expect(response).to have_http_status(:found)

    get "/admin/component-comparison"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ops-component@example.com")
    expect(response.body).to include("/admin/logout")
  end

  it "redirects to root when ADMIN_UI_TOKEN is set and token is missing" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/component-comparison"

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")
  end

  it "allows access via role-based policy when ADMIN_UI_TOKEN is set" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/component-comparison", headers: { "X-Admin-User" => "alice", "X-Admin-Role" => "viewer" }

    expect(response).to have_http_status(:ok)
  end

  it "renders drilldown table and empty-state variants for default/loading/empty/error" do
    get "/admin/component-comparison", headers: { "X-Admin-User" => "alice", "X-Admin-Role" => "viewer" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("DataTable: default")
    expect(response.body).to include("DataTable: loading")
    expect(response.body).to include("EmptyState: empty")
    expect(response.body).to include("EmptyState: error")
    expect(response.body).to include("No account totals available.")
    expect(response.body).to include("Loading dashboard data...")
    expect(response.body).to include("Dashboard source unavailable.")
  end
end
