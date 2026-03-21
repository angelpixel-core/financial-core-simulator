require "rails_helper"

RSpec.describe "Dashboard overview", type: :request do
  it "returns complete snapshot shape for overview widgets" do
    get "/dashboard/overview", as: :json

    expect(response).to have_http_status(:ok)

    parsed = JSON.parse(response.body)
    expect(parsed).to include("runKpis", "runsTrend14d", "statusMix30d", "latestRun", "globalSummary", "topAccounts")
    expect(parsed.fetch("runKpis")).to include("totalRuns7d", "totalRuns30d", "successRateLast50",
      "avgDurationMsLast50")
    expect(parsed.fetch("runsTrend14d")).to be_a(Array)
    expect(parsed.fetch("statusMix30d")).to include("queued", "running", "succeeded", "failed")
    expect(parsed.fetch("topAccounts")).to be_a(Array)
  end

  it "returns forbidden when ADMIN_UI_TOKEN is configured and token is missing" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/dashboard/overview", as: :json

    expect(response).to have_http_status(:forbidden)
  end
end
