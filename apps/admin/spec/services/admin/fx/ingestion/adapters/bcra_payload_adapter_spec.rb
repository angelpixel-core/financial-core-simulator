require "rails_helper"

RSpec.describe Admin::Fx::Ingestion::Adapters::BcraPayloadAdapter do
  it "exposes entries and details with typed fields" do
    payload = {
      "results" => [
        {
          "fecha" => "2024-06-12",
          "detalle" => [
            {"codigoMoneda" => "USD", "tipoCotizacion" => "901.5"}
          ]
        }
      ]
    }

    adapter = described_class.new(payload)
    entry = adapter.entries.first
    detail = entry.details.first

    expect(entry.date).to eq(Date.new(2024, 6, 12))
    expect(detail.currency_code).to eq("USD")
    expect(detail.rate.to_s("F")).to eq("901.5")
  end

  it "raises a strict error when date is invalid" do
    payload = {
      "results" => [
        {
          "fecha" => "invalid",
          "detalle" => [
            {"codigoMoneda" => "USD", "tipoCotizacion" => "901.5"}
          ]
        }
      ]
    }

    adapter = described_class.new(payload)

    expect { adapter.entries.first.date }
      .to raise_error(Admin::Fx::Ingestion::Adapters::BcraPayloadAdapter::Error)
  end
end
