require "rails_helper"

RSpec.describe Admin::Fx::Ingestion::Mappers::BinanceRateMapper do
  let(:source) do
    FxRateSource.create!(
      name: "Binance Spot",
      code: "BINANCE_SPOT",
      source_type: "api",
      version: "v1",
      config: {
        "markets" => ["BTCUSDT", "ETHUSDT"]
      }
    )
  end

  it "maps klines payload entries into value objects" do
    payload = {
      "status" => 200,
      "metadata" => {
        "resultset" => {"count" => 1, "offset" => 0, "limit" => 1000},
        "market" => "BTCUSDT",
        "interval" => "1d"
      },
      "results" => [
        {
          "open_time" => 1_717_200_000_000,
          "close" => "68432.12",
          "close_time" => 1_717_286_399_999
        }
      ]
    }

    result = described_class.call(payload: payload, source: source, market: "BTCUSDT")

    expect(result).to be_success
    rates = result.data.fetch(:rates)
    expect(rates.length).to eq(1)

    rate = rates.first
    expect(rate.operational_date).to eq(Date.new(2024, 6, 1))
    expect(rate.base_currency).to eq("BTC")
    expect(rate.quote_currency).to eq("USD")
    expect(rate.rate.to_s("F")).to eq("68432.12")
  end

  it "maps ETHUSDT to ETH/USD" do
    payload = {
      "status" => 200,
      "metadata" => {
        "resultset" => {"count" => 1, "offset" => 0, "limit" => 1000},
        "market" => "ETHUSDT",
        "interval" => "1d"
      },
      "results" => [
        {
          "open_time" => 1_717_200_000_000,
          "close" => "3600.00",
          "close_time" => 1_717_286_399_999
        }
      ]
    }

    result = described_class.call(payload: payload, source: source, market: "ETHUSDT")

    expect(result).to be_success
    rate = result.data.fetch(:rates).first
    expect(rate.base_currency).to eq("ETH")
    expect(rate.quote_currency).to eq("USD")
  end

  it "returns failure when market is unsupported" do
    payload = {
      "status" => 200,
      "metadata" => {
        "resultset" => {"count" => 0, "offset" => 0, "limit" => 1000},
        "market" => "DOGEUSDT",
        "interval" => "1d"
      },
      "results" => []
    }

    result = described_class.call(payload: payload, source: source, market: "DOGEUSDT")

    expect(result).to be_failure
    expect(result.error_code).to eq("invalid_market")
  end
end
