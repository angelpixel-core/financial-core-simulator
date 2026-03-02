require "rails_helper"

RSpec.describe "Admin component comparison", type: :request do
  it "renders both ViewComponent and Phlex cards" do
    get "/admin/component-comparison"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Component Comparison: ViewComponent vs Phlex")
    expect(response.body).to include("ViewComponent")
    expect(response.body).to include("Phlex")
    expect(response.body).to include("Success rate (last 50)")
  end

  it "returns forbidden when ADMIN_UI_TOKEN is set and token is missing" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/component-comparison"

    expect(response).to have_http_status(:forbidden)
  end

  it "allows access via role-based policy when ADMIN_UI_TOKEN is set" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/component-comparison", headers: { "X-Admin-User" => "alice", "X-Admin-Role" => "viewer" }

    expect(response).to have_http_status(:ok)
  end
end
