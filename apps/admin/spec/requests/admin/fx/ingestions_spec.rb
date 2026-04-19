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
    expect(response).to have_http_status(:ok)
  end

  it "forbids viewers" do
    post "/admin/fx/ingestions/sync", params: {source_id: source.id, market: "USDARS"},
      headers: admin_session_headers(role: "viewer")

    expect(response).to have_http_status(:forbidden)
  end

  def admin_session_headers(role: "operator")
    {"X-Admin-User" => "ops", "X-Admin-Role" => role}
  end
end
