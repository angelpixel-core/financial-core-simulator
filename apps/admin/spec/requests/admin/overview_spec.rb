require "rails_helper"

RSpec.describe "Admin overview", type: :request do
  it "renders empty state without exploding when no runs exist" do
    get "/admin/overview"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Financial Overview")
    expect(response.body).to include("No succeeded runs yet.")
    expect(response.body).to include("data-controller=\"poll\"")
  end

  it "renders top accounts partial endpoint" do
    get "/admin/overview/top-accounts"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Top accounts (live)")
    expect(response.body).to include("Back to overview")
  end

  it "renders top accounts fragment for xhr polling" do
    get "/admin/overview/top-accounts", headers: { "X-Requested-With" => "XMLHttpRequest" }

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

  it "allows access when ADMIN_UI_TOKEN is provided" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/overview", headers: { "X-Admin-Token" => "ui-secret" }

    expect(response).to have_http_status(:ok)
  end
end
