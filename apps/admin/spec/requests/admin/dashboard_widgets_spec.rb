require "rails_helper"

RSpec.describe "Dashboard widgets", type: :request do
  it "returns isolated payload for top accounts widget" do
    get "/dashboard/top-accounts", as: :json

    expect(response).to have_http_status(:ok)

    parsed = JSON.parse(response.body)
    expect(parsed.keys).to eq([ "topAccounts" ])
    expect(parsed.fetch("topAccounts")).to be_a(Array)
  end

  it "returns isolated payload for risk widget" do
    get "/dashboard/risk", as: :json

    expect(response).to have_http_status(:ok)

    parsed = JSON.parse(response.body)
    expect(parsed.keys).to eq([ "riskView" ])
    expect(parsed.fetch("riskView")).to be_a(Hash)
  end

  it "returns isolated payload for trend widget" do
    get "/dashboard/trend", as: :json

    expect(response).to have_http_status(:ok)

    parsed = JSON.parse(response.body)
    expect(parsed.keys).to eq([ "runsTrend14d" ])
    expect(parsed.fetch("runsTrend14d")).to be_a(Array)
  end

  it "returns isolated payload for latest run widget" do
    get "/dashboard/latest-run", as: :json

    expect(response).to have_http_status(:ok)

    parsed = JSON.parse(response.body)
    expect(parsed.keys).to eq([ "latestRun" ])
  end

  it "returns forbidden for widget endpoints when ADMIN_UI_TOKEN is configured and token is missing" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/dashboard/top-accounts", as: :json

    expect(response).to have_http_status(:forbidden)
  end
end
