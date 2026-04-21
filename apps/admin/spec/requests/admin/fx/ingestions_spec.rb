require "rails_helper"

RSpec.describe "Admin FX ingestions", type: :request do
  include ActiveJob::TestHelper

  let(:source) do
    FxRateSource.create!(
      name: "Banco Central",
      code: "BCRA",
      source_type: "api",
      version: "v1",
      config: {"base_url" => "https://api.bcra.gob.ar/estadisticascambiarias/v1.0"}
    )
  end

  it "enqueues sync jobs for operators" do
    expect do
      post "/admin/fx/ingestions/sync", params: {source_id: source.id, market: "USDARS"},
        headers: admin_session_headers.merge("Accept" => "text/vnd.turbo-stream.html")
    end.to have_enqueued_job(Admin::Fx::FetchFxRatesJob)

    ingestion = FxRateIngestion.last
    expect(ingestion.status).to eq("pending")
    expect(ingestion.metadata["market"]).to eq("USDARS")
    expect(ingestion.metadata["requested_by_role"]).to be_present
    expect(response).to have_http_status(:found)
  end

  it "forbids viewers" do
    post "/admin/fx/ingestions/sync", params: {source_id: source.id, market: "USDARS"},
      headers: admin_session_headers(role: "viewer")

    expect(response).to have_http_status(:forbidden)
  end

  it "returns latest ingestion status filtered by source id" do
    ingestion = FxRateIngestion.create!(
      source: source,
      status: "running",
      correlation_id: SecureRandom.uuid,
      metadata: {"market" => "USDARS"}
    )

    get "/admin/fx/ingestions.json", params: {source_id: source.id}, headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body.fetch("sources").size).to eq(1)
    payload = body.fetch("sources").first
    expect(payload.fetch("source_id")).to eq(source.id)
    expect(payload.fetch("ingestion_id")).to eq(ingestion.id)
    expect(payload.fetch("status")).to eq("running")
  end

  def admin_session_headers(role: "operator")
    {"X-Admin-User" => "ops", "X-Admin-Role" => role}
  end
end
