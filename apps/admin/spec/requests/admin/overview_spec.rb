require "rails_helper"

RSpec.describe "Admin overview", type: :request do
  it "renders empty state without exploding when no runs exist" do
    get "/admin/overview"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Financial Overview")
    expect(response.body).to include("No succeeded runs yet.")
  end
end
