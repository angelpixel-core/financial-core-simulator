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

  let(:binance_source) do
    FxRateSource.create!(
      name: "Binance Spot",
      code: "BINANCE_SPOT",
      source_type: "api",
      version: "v1",
      config: {
        "base_url" => "https://api.binance.com",
        "interval" => "1d",
        "markets" => ["BTCUSDT", "ETHUSDT"]
      }
    )
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
    rate = Admin::Fx::ValueObjects::FxRate.new(
      operational_date: Date.new(2024, 6, 1),
      base_currency: "USD",
      quote_currency: "ARS",
      rate: "900.5",
      source_id: source.id,
      source_code: source.code
    )
    mapper_result = Admin::Fx::Ingestion::Result.success(data: {rates: [rate]})
    allow(Admin::Fx::Ingestion::Mappers::BcraRateMapper).to receive(:call).and_return(mapper_result)
    allow(Admin::Fx::RateUpserter).to receive(:call)

    described_class.perform_now(source.id)

    ingestion = FxRateIngestion.last
    expect(ingestion.status).to eq("success")
    expect(FxRateEvent.where(event_type: "fx_rate.ingested")).to exist
    expect(FxRateEvent.where(event_type: "fx_rate.persisted")).to exist
    expect(Admin::Fx::RateUpserter).to have_received(:call)
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

  it "marks ingestion as failed on mapping errors" do
    allow(adapter).to receive(:default_range).and_return([Date.new(2024, 6, 1), Date.new(2024, 6, 30)])
    allow(adapter).to receive(:fetch).and_return(
      Admin::Fx::Ingestion::Result.success(data: {payload: payload})
    )
    validation = instance_double(Dry::Validation::Result, success?: true)
    contract = instance_double(Admin::Fx::Ingestion::Validators::BcraContract, call: validation)
    allow(Admin::Fx::Ingestion::Validators::BcraContract).to receive(:new).and_return(contract)
    mapper_result = Admin::Fx::Ingestion::Result.failure(
      error_code: "mapping_failed",
      context: {errors: [{message: "bad"}]}
    )
    allow(Admin::Fx::Ingestion::Mappers::BcraRateMapper).to receive(:call).and_return(mapper_result)

    described_class.perform_now(source.id)

    ingestion = FxRateIngestion.last
    expect(ingestion.status).to eq("failed")
    expect(ingestion.error_code).to eq("mapping_failed")
    expect(FxRateEvent.where(event_type: "fx_rate.mapping_failed")).to exist
  end

  it "uses binance validator and mapper for BINANCE_SPOT source" do
    binance_adapter = instance_double(Admin::Fx::Ingestion::Adapters::BinanceAdapter)
    allow(Admin::Fx::Ingestion::AdapterRegistry).to receive(:build).with(binance_source).and_return(binance_adapter)
    allow(binance_adapter).to receive(:default_range).and_return([Date.new(2024, 6, 1), Date.new(2024, 6, 30)])
    allow(binance_adapter).to receive(:fetch).and_return(
      Admin::Fx::Ingestion::Result.success(
        data: {
          payload: {
            "status" => 200,
            "metadata" => {"resultset" => {"count" => 1, "offset" => 0, "limit" => 1000}, "market" => "BTCUSDT", "interval" => "1d"},
            "results" => [{"open_time" => 1_717_200_000_000, "close" => "68432.12", "close_time" => 1_717_286_399_999}]
          }
        }
      )
    )
    validation = instance_double(Dry::Validation::Result, success?: true)
    contract = instance_double(Admin::Fx::Ingestion::Validators::BinanceContract, call: validation)
    allow(Admin::Fx::Ingestion::Validators::BinanceContract).to receive(:new).and_return(contract)
    rate = Admin::Fx::ValueObjects::FxRate.new(
      operational_date: Date.new(2024, 6, 1),
      base_currency: "BTC",
      quote_currency: "USD",
      rate: "68432.12",
      source_id: binance_source.id,
      source_code: binance_source.code
    )
    mapper_result = Admin::Fx::Ingestion::Result.success(data: {rates: [rate]})
    allow(Admin::Fx::Ingestion::Mappers::BinanceRateMapper).to receive(:call).and_return(mapper_result)
    allow(Admin::Fx::RateUpserter).to receive(:call)

    described_class.perform_now(binance_source.id, market: "BTCUSDT")

    expect(Admin::Fx::Ingestion::Validators::BinanceContract).to have_received(:new)
    expect(Admin::Fx::Ingestion::Mappers::BinanceRateMapper).to have_received(:call)
    expect(Admin::Fx::RateUpserter).to have_received(:call)
  end
end
