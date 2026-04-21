require "rails_helper"

RSpec.describe Admin::Fx::Providers::BcraClient do
  subject(:client) { described_class.new }

  let(:operational_date) { Date.new(2026, 4, 21) }

  it "fetches USD/ARS using USD endpoint" do
    response = instance_double(
      Net::HTTPOK,
      code: "200",
      body: {
        "results" => [
          {
            "fecha" => "2026-04-21",
            "detalle" => [
              {"codigoMoneda" => "USD", "tipoCotizacion" => "1000"}
            ]
          }
        ]
      }.to_json
    )
    allow(Net::HTTP).to receive(:get_response).and_return(response)

    payload = client.fetch_official_rate(base_currency: "USD", quote_currency: "ARS", at: operational_date)

    expect(payload).to eq("results" => [{"date" => "2026-04-21", "close" => "1000"}])
    expect(Net::HTTP).to have_received(:get_response) do |uri|
      expect(uri.to_s).to include("/Cotizaciones/USD?")
    end
  end

  it "fetches EUR/ARS using EUR endpoint" do
    response = instance_double(
      Net::HTTPOK,
      code: "200",
      body: {
        "results" => [
          {
            "fecha" => "2026-04-21",
            "detalle" => [
              {"codigoMoneda" => "EUR", "tipoCotizacion" => "1200"}
            ]
          }
        ]
      }.to_json
    )
    allow(Net::HTTP).to receive(:get_response).and_return(response)

    payload = client.fetch_official_rate(base_currency: "EUR", quote_currency: "ARS", at: operational_date)

    expect(payload).to eq("results" => [{"date" => "2026-04-21", "close" => "1200"}])
    expect(Net::HTTP).to have_received(:get_response) do |uri|
      expect(uri.to_s).to include("/Cotizaciones/EUR?")
    end
  end

  it "raises rate limited error when BCRA responds 429" do
    response = instance_double(Net::HTTPTooManyRequests, code: "429", body: "")
    allow(Net::HTTP).to receive(:get_response).and_return(response)

    expect {
      client.fetch_official_rate(base_currency: "USD", quote_currency: "ARS", at: operational_date)
    }.to raise_error(Admin::Fx::Providers::BcraClient::RateLimitedError)
  end

  it "raises not implemented for unsupported non-ARS cross" do
    expect {
      client.fetch_official_rate(base_currency: "BTC", quote_currency: "USD", at: operational_date)
    }.to raise_error(NotImplementedError)
  end
end
