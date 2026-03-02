require "rails_helper"

RSpec.describe "Admin routing compatibility", type: :request do
  it "redirects legacy /avo root to /admin" do
    get "/avo"

    expect(response).to have_http_status(:moved_permanently)
    expect(response.headers["Location"]).to end_with("/admin")
  end
end
