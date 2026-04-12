require "rails_helper"
require "securerandom"

RSpec.describe FxRateLineage, type: :model do
  it "requires currencies, status, and correlation_id" do
    lineage = described_class.new

    expect(lineage).not_to be_valid
    expect(lineage.errors[:operational_date]).to include("can't be blank")
    expect(lineage.errors[:base_currency]).to include("can't be blank")
    expect(lineage.errors[:quote_currency]).to include("can't be blank")
    expect(lineage.errors[:status]).to include("can't be blank")
    expect(lineage.errors[:correlation_id]).to include("can't be blank")
  end

  it "accepts known statuses" do
    source = FxRateSource.create!(
      name: "Banco Central",
      code: "BCRA",
      source_type: "api",
      version: "v1",
      config: {"base_currency" => "USD", "quote_currency" => "ARS"}
    )
    ingestion = FxRateIngestion.create!(
      source: source,
      status: "running",
      correlation_id: SecureRandom.uuid
    )

    lineage = described_class.new(
      ingestion: ingestion,
      source: source,
      operational_date: Date.new(2026, 4, 10),
      base_currency: "USD",
      quote_currency: "ARS",
      status: "persisted",
      correlation_id: SecureRandom.uuid
    )

    expect(lineage).to be_valid
  end
end
