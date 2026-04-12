require "rails_helper"

RSpec.describe Admin::Fx::FetchFxRatesJob, type: :job do
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

  let(:adapter) do
    instance_double(Admin::Fx::Ingestion::Adapters::BcraAdapter)
  end

  let(:payload) do
    {
      "status" => 200,
      "metadata" => {"resultset" => {"count" => 1, "offset" => 0, "limit" => 1000}},
      "results" => []
    }
  end

  before do
    allow(Admin::Fx::Ingestion::AdapterRegistry).to receive(:build).and_return(adapter)
  end

  it "creates ingestion and emits events on success" do
    allow(adapter).to receive(:default_range).and_return([Date.new(2024, 6, 1), Date.new(2024, 6, 30)])
    allow(adapter).to receive(:fetch).and_return(
      Admin::Fx::Ingestion::Result.success(data: {payload: payload})
    )
    validation = instance_double(Dry::Validation::Result, success?: true)
    contract = instance_double(Admin::Fx::Ingestion::Validators::BcraContract, call: validation)
    allow(Admin::Fx::Ingestion::Validators::BcraContract).to receive(:new).and_return(contract)

    described_class.perform_now(source.id)

    ingestion = FxRateIngestion.last
    expect(ingestion.status).to eq("success")
    expect(FxRateEvent.where(event_type: "fx_rate.ingested")).to exist
    expect(FxRateEvent.where(event_type: "fx_rate.persisted")).to exist
  end

  it "marks ingestion as failed on adapter errors" do
    allow(adapter).to receive(:default_range).and_return([Date.new(2024, 6, 1), Date.new(2024, 6, 30)])
    allow(adapter).to receive(:fetch).and_return(
      Admin::Fx::Ingestion::Result.failure(error_code: "http_error", context: {status: 500})
    )

    described_class.perform_now(source.id)

    ingestion = FxRateIngestion.last
    expect(ingestion.status).to eq("failed")
    expect(ingestion.error_code).to eq("http_error")
    expect(FxRateEvent.where(event_type: "fx_rate.fetch_failed")).to exist
  end
end
