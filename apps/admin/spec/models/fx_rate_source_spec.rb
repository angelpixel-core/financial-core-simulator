require "rails_helper"

RSpec.describe FxRateSource, type: :model do
  it "is valid with required attributes" do
    source = described_class.new(
      name: "Banco Central",
      code: "BCRA",
      source_type: "api",
      version: "v1",
      config: {"base_currency" => "USD", "quote_currency" => "ARS"}
    )

    expect(source).to be_valid
  end

  it "requires a supported source_type" do
    source = described_class.new(
      name: "Manual",
      code: "MAN",
      source_type: "unknown",
      version: "v1",
      config: {}
    )

    expect(source).not_to be_valid
    expect(source.errors[:source_type]).to include("is not included in the list")
  end
end
