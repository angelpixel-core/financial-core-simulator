require "rails_helper"

RSpec.describe Admin::Fx::Ingestion::LogPayload do
  it "includes required keys with nil values" do
    source = FxRateSource.create!(
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
    ingestion = FxRateIngestion.create!(
      source: source,
      status: "failed",
      correlation_id: "c1",
      error_code: "http_error"
    )

    payload = described_class.call(
      ingestion: ingestion,
      source: source,
      message: "Fx ingestion mapping failed",
      error_code: nil,
      severity: nil,
      extra: {error_count: 2}
    )

    expect(payload).to include(
      ingestion_id: ingestion.id,
      source_code: "BCRA",
      error_code: nil,
      severity: nil
    )
    expect(payload[:error_count]).to eq(2)
  end
end
