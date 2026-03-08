require "rails_helper"

RSpec.describe "Public landing", type: :request do
  it "renders public root landing content" do
    get "/"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Financial Core Simulator")
    expect(response.body).to include("Deterministic financial ledger simulation")
    expect(response.body).to include("View Demo")
    expect(response.body).to include("GitHub")
    expect(response.body).to include("Documentation")
  end

  it "keeps root publicly reachable when ADMIN_UI_TOKEN is configured" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Financial Core Simulator")
  end

  it "exposes CTA links to admin login and source/doc destinations" do
    get "/"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('href="/admin/login"')
    expect(response.body).to include("View source")
    expect(response.body).to include("Documentation")
  end
end
