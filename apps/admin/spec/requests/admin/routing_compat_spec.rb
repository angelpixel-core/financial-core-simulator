require "rails_helper"

RSpec.describe "Admin routing compatibility", type: :request do
  it "redirects legacy /avo root to /admin" do
    get "/avo"

    expect(response).to have_http_status(:moved_permanently)
    expect(response.headers["Location"]).to end_with("/admin")
  end

  it "forbids Avo resources access when ADMIN_UI_TOKEN is set and missing" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/resources/runs"

    expect(response).to have_http_status(:forbidden)
  end
end
