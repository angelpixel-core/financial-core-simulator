require "rails_helper"

RSpec.describe Admin::Fx::Ingestion::Adapters::BcraAdapter do
  subject(:adapter) { described_class.new(source: source) }

  let(:source) do
    FxRateSource.create!(
      name: "Banco Central",
      code: "BCRA",
      source_type: "api",
      version: "v1",
      config: {
        "base_url" => "https://api.bcra.gob.ar/estadisticascambiarias/v1.0",
        "base_currency" => "USD",
        "currency_code" => "USD"
      }
    )
  end

  let(:success_response) do
    instance_double(Net::HTTPSuccess, code: "200",
      body: '{"status":200,"metadata":{"resultset":{"count":0,"offset":0,"limit":1000}},"results":[]}')
  end

  it "returns a success result with payload", :vcr, cassette_name: "bcra_success" do
    result = adapter.fetch(date_from: Date.new(2024, 6, 12), date_to: Date.new(2024, 6, 12))

    expect(result).to be_success
    expect(result.data[:payload]["status"]).to eq(200)
    expect(result.metadata[:status]).to eq(200)
  end

  it "returns failure for missing base_url" do
    source.update!(config: {"currency_code" => "USD"})

    result = adapter.fetch(date_from: Date.new(2026, 4, 1), date_to: Date.new(2026, 4, 2))

    expect(result).to be_failure
    expect(result.error_code).to eq("missing_config")
    expect(result.context[:missing_key]).to eq("base_url")
  end

  it "returns failure for invalid json" do
    bad_response = instance_double(Net::HTTPSuccess, code: "200", body: "{invalid")
    allow(Net::HTTP).to receive(:get_response).and_return(bad_response)

    result = adapter.fetch(date_from: Date.new(2026, 4, 1), date_to: Date.new(2026, 4, 2))

    expect(result).to be_failure
    expect(result.error_code).to eq("invalid_json")
  end

  it "returns failure for non-success status" do
    error_response = instance_double(Net::HTTPServerError, code: "500", body: "error")
    allow(Net::HTTP).to receive(:get_response).and_return(error_response)

    result = adapter.fetch(date_from: Date.new(2026, 4, 1), date_to: Date.new(2026, 4, 2))

    expect(result).to be_failure
    expect(result.error_code).to eq("http_error")
    expect(result.context[:status]).to eq(500)
  end

  it "builds a 30-day default range" do
    from_date, to_date = adapter.default_range(to_date: Date.new(2026, 4, 12))

    expect(from_date).to eq(Date.new(2026, 3, 14))
    expect(to_date).to eq(Date.new(2026, 4, 12))
  end
end
