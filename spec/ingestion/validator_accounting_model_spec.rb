# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Ingestion::Validator do
  def base_input
    {
      "schemaVersion" => "1.0",
      "accounts" => [{"accountId" => "acc-1"}],
      "markets" => [{"marketId" => "ETH-USD"}],
      "trades" => [],
      "priceSnapshot" => {
        "valuationTimestamp" => "2026-02-25T03:00:00Z",
        "prices" => [{"marketId" => "ETH-USD", "priceQuotePerBase" => "100"}]
      }
    }
  end

  it "accepts FIFO accounting model" do
    input = base_input.merge("accountingModel" => {"method" => "FIFO"})

    expect { described_class.new.validate!(input) }.not_to raise_error
  end

  it "rejects unsupported accounting model" do
    input = base_input.merge("accountingModel" => {"method" => "LIFO"})

    expect { described_class.new.validate!(input) }.to raise_error(FCS::Error) { |e|
      expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
    }
  end

  it "accepts riskModel.maxLeverage and accounts collateralQuote" do
    input = base_input.merge(
      "riskModel" => {"maxLeverage" => "2"},
      "accounts" => [{"accountId" => "acc-1", "collateralQuote" => "100"}]
    )

    expect { described_class.new.validate!(input) }.not_to raise_error
  end

  it "rejects non-positive maxLeverage" do
    input = base_input.merge("riskModel" => {"maxLeverage" => "0"})

    expect { described_class.new.validate!(input) }.to raise_error(FCS::Error) { |e|
      expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
    }
  end

  it "rejects invalid maintenanceMarginRatio above configured bound" do
    input = base_input.merge("riskModel" => {"maintenanceMarginRatio" => "0.99"})

    expect { described_class.new.validate!(input) }.to raise_error(FCS::Error) { |e|
      expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
      expect(e.details[:field]).to eq("riskModel.maintenanceMarginRatio")
    }
  end

  it "rejects missing liquidation.closeFactor when liquidation config is present" do
    input = base_input.merge("riskModel" => {"liquidation" => {"enabled" => true}})

    expect { described_class.new.validate!(input) }.to raise_error(FCS::Error) { |e|
      expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
      expect(e.details[:field]).to eq("riskModel.liquidation.closeFactor")
    }
  end

  it "accepts valid maintenanceMarginRatio and liquidation.closeFactor" do
    input = base_input.merge(
      "riskModel" => {
        "maintenanceMarginRatio" => "0.25",
        "liquidation" => {
          "enabled" => true,
          "closeFactor" => "0.5"
        }
      }
    )

    expect { described_class.new.validate!(input) }.not_to raise_error
  end

  it "rejects non-boolean liquidation.enabled" do
    input = base_input.merge(
      "riskModel" => {
        "liquidation" => {"enabled" => "yes", "closeFactor" => "0.5"}
      }
    )

    expect { described_class.new.validate!(input) }.to raise_error(FCS::Error) { |e|
      expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
      expect(e.details[:field]).to eq("riskModel.liquidation.enabled")
    }
  end

  it "rejects usdModel without enabled flag" do
    input = base_input.merge("usdModel" => {})

    expect { described_class.new.validate!(input) }.to raise_error(FCS::Error) { |e|
      expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
      expect(e.details[:field]).to eq("usdModel.enabled")
    }
  end
end
