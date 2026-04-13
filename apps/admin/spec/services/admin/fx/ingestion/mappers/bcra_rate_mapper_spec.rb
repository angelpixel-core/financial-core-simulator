require "rails_helper"

RSpec.describe Admin::Fx::Ingestion::Mappers::BcraRateMapper do
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

  it "maps payload entries into value objects" do
    payload = {
      "status" => 200,
      "metadata" => {"resultset" => {"count" => 1, "offset" => 0, "limit" => 1000}},
      "results" => [
        {
          "fecha" => "2024-06-12",
          "detalle" => [
            {"codigoMoneda" => "USD", "tipoCotizacion" => "901.5"}
          ]
        }
      ]
    }

    result = described_class.call(payload: payload, source: source)

    expect(result).to be_success
    rates = result.data.fetch(:rates)
    expect(rates.length).to eq(1)

    rate = rates.first
    expect(rate.operational_date).to eq(Date.new(2024, 6, 12))
    expect(rate.base_currency).to eq("USD")
    expect(rate.quote_currency).to eq("ARS")
    expect(rate.rate.to_s("F")).to eq("901.5")
    expect(rate.source_id).to eq(source.id)
    expect(rate.source_code).to eq("BCRA")
  end

  it "returns failure when mapping encounters invalid values" do
    payload = {
      "status" => 200,
      "metadata" => {"resultset" => {"count" => 1, "offset" => 0, "limit" => 1000}},
      "results" => [
        {
          "fecha" => "invalid",
          "detalle" => [
            {"codigoMoneda" => "USD", "tipoCotizacion" => "0"}
          ]
        }
      ]
    }

    result = described_class.call(payload: payload, source: source)

    expect(result).to be_failure
    expect(result.error_code).to eq("mapping_failed")
    expect(result.context[:errors]).not_to be_empty
    expect(result.context[:errors].first[:raw_entry]).to be_present
  end
end
