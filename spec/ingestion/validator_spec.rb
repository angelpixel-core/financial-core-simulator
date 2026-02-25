# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Ingestion::Validator do
  subject(:validator) { described_class.new }

  def base_input
    {
      "schemaVersion" => "1.0",
      "accounts" => [{ "accountId" => "acc-1" }],
      "markets" => [{ "marketId" => "ETH-USD" }],
      "trades" => [],
      "priceSnapshot" => {
        "valuationTimestamp" => "2026-02-25T03:00:00Z",
        "prices" => [
          { "marketId" => "ETH-USD", "priceQuotePerBase" => "2500" }
        ],
        "fx" => { "quoteUsd" => "1" }
      }
    }
  end

  it "falla si falta priceSnapshot" do
    input = base_input
    input.delete("priceSnapshot")

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        # tu validator actual usa ERR_VALIDATION para missing required field
        expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(e.details).to include(field: "priceSnapshot")
      }
  end

  it "falla si falta precio para un market" do
    input = base_input
    input["markets"] = [{ "marketId" => "ETH-USD" }, { "marketId" => "BTC-USD" }]
    # Snapshot solo tiene ETH-USD
    input["priceSnapshot"]["prices"] = [
      { "marketId" => "ETH-USD", "priceQuotePerBase" => "2500" }
    ]

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_MISSING_SNAPSHOT)
        expect(e.details).to have_key(:missingMarkets)
        expect(e.details[:missingMarkets]).to include("BTC-USD")
      }
  end

  it "falla si trade referencia market inexistente" do
    input = base_input
    input["trades"] = [
      {
        "tradeId" => "t-1",
        "accountId" => "acc-1",
        "marketId" => "BTC-USD", # inexistente
        "timestamp" => 1,
        "seq" => 1,
        "side" => "BUY",
        "quantityBase" => "1",
        "priceQuotePerBase" => "100"
      }
    ]

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_UNKNOWN_REFERENCE)
        expect(e.details).to include(marketId: "BTC-USD")
      }
  end

  it "falla si hay float en quantityBase" do
    input = base_input
    input["trades"] = [
      {
        "tradeId" => "t-1",
        "accountId" => "acc-1",
        "marketId" => "ETH-USD",
        "timestamp" => 1,
        "seq" => 1,
        "side" => "BUY",
        "quantityBase" => 1.23, # Float => debe fallar
        "priceQuotePerBase" => "100"
      }
    ]

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_INVALID_NUMBER)
        expect(e.message).to match(/Float not allowed/i)
        expect(e.details).to include(field: "quantityBase")
      }
  end
end
