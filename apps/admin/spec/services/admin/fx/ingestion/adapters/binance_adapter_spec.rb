require "rails_helper"

RSpec.describe Admin::Fx::Ingestion::Adapters::BinanceAdapter do
  subject(:adapter) { described_class.new(source: source) }

  let(:source) do
    FxRateSource.create!(
      name: "Binance Spot",
      code: "BINANCE_SPOT",
      source_type: "api",
      version: "v1",
      config: {
        "base_url" => "https://api.binance.com",
        "interval" => "1d",
        "default_limit" => 1000,
        "markets" => ["BTCUSDT", "ETHUSDT"]
      }
    )
  end

  it "returns success with normalized kline payload", vcr: {cassette_name: "admin/fx/ingestion/adapters/binance/btcusdt_success"} do
    result = adapter.fetch(
      date_from: Date.new(2024, 6, 1),
      date_to: Date.new(2024, 6, 10),
      market: "BTCUSDT"
    )

    expect(result).to be_success
    payload = result.data.fetch(:payload)
    expect(payload["status"]).to eq(200)
    expect(payload.dig("metadata", "market")).to eq("BTCUSDT")
    expect(payload.fetch("results")).not_to be_empty
    expect(payload.fetch("results").first).to include("open_time", "close", "close_time")
  end

  it "records ETHUSDT klines with VCR", vcr: {cassette_name: "admin/fx/ingestion/adapters/binance/ethusdt_success"} do
    result = adapter.fetch(
      date_from: Date.new(2024, 6, 1),
      date_to: Date.new(2024, 6, 10),
      market: "ETHUSDT"
    )

    expect(result).to be_success
    payload = result.data.fetch(:payload)
    expect(payload.dig("metadata", "market")).to eq("ETHUSDT")
    expect(payload.fetch("results")).not_to be_empty
  end

  it "returns failure for invalid market" do
    result = adapter.fetch(date_from: Date.new(2026, 4, 1), date_to: Date.new(2026, 4, 2), market: "DOGEUSDT")

    expect(result).to be_failure
    expect(result.error_code).to eq("invalid_market")
  end

  it "returns failure for non-success status" do
    error_response = instance_double(Net::HTTPServerError, code: "500", body: "error")
    allow(Net::HTTP).to receive(:get_response).and_return(error_response)

    result = adapter.fetch(date_from: Date.new(2026, 4, 1), date_to: Date.new(2026, 4, 2), market: "BTCUSDT")

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
