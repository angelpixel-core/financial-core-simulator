require "rails_helper"

RSpec.describe Runs::ErrorCodeMapper do
  it "maps validation field subtypes for richer analytics" do
    risk_error = FCS::Error.new(FCS::Errors::ERR_VALIDATION, "bad risk", details: { field: "riskModel.maxLeverage" })
    accounting_error = FCS::Error.new(FCS::Errors::ERR_VALIDATION, "bad accounting", details: { field: "accountingModel.method" })
    collateral_error = FCS::Error.new(FCS::Errors::ERR_VALIDATION, "bad collateral", details: { field: "accounts.collateralQuote" })
    number_error = FCS::Error.new(FCS::Errors::ERR_VALIDATION, "bad qty", details: { field: "quantityBase" })

    expect(described_class.call(risk_error)).to eq("ERR_VALIDATION_RISK_MODEL")
    expect(described_class.call(accounting_error)).to eq("ERR_VALIDATION_ACCOUNTING_MODEL")
    expect(described_class.call(collateral_error)).to eq("ERR_VALIDATION_COLLATERAL")
    expect(described_class.call(number_error)).to eq("ERR_VALIDATION_TRADE_DECIMAL")
  end

  it "maps core domain subtype codes" do
    unknown_ref = FCS::Error.new(FCS::Errors::ERR_UNKNOWN_REFERENCE, "unknown")
    duplicate_seq = FCS::Error.new(FCS::Errors::ERR_DUPLICATE_SEQ, "dup")

    expect(described_class.call(unknown_ref)).to eq("ERR_VALIDATION_UNKNOWN_REFERENCE")
    expect(described_class.call(duplicate_seq)).to eq("ERR_VALIDATION_DUPLICATE_SEQ")
  end
end
