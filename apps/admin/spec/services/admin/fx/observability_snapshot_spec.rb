require "rails_helper"

RSpec.describe Admin::Fx::ObservabilitySnapshot do
  let(:source) do
    FxRateSource.create!(
      name: "Banco Central",
      code: "BCRA",
      source_type: "api",
      version: "v1",
      config: {
        "base_currency" => "USD",
        "quote_currency" => "ARS",
        "base_url" => "https://api.bcra.gob.ar/estadisticascambiarias/v1.0",
        "currency_code" => "USD"
      }
    )
  end

  it "builds summary counts and events" do
    FxRateIngestion.create!(source: source, status: "success", correlation_id: "c1")
    FxRateIngestion.create!(source: source, status: "failed", correlation_id: "c2", error_code: "http_error")
    FxRateEvent.create!(
      event_type: "fx_rate.fetch_failed",
      data: {"error_code" => "http_error", "severity" => "error", "source_id" => source.id},
      metadata: {"ingestion_id" => 1, "source_id" => source.id}
    )

    snapshot = described_class.call(source_id: source.id, days: 7)

    expect(snapshot[:summary][:total]).to eq(2)
    expect(snapshot[:summary][:failed]).to eq(1)
    expect(snapshot[:failures_by_code].first[:error_code]).to eq("http_error")
    expect(snapshot[:failures_by_code].first[:time_bucket]).to be_present
    expect(snapshot[:events].first[:event_type]).to eq("fx_rate.fetch_failed")
    expect(snapshot[:events].first[:time_bucket]).to be_present
  end
end
