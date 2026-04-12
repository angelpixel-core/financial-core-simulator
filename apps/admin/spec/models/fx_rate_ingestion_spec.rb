require "rails_helper"
require "securerandom"

RSpec.describe FxRateIngestion, type: :model do
  it "requires status and correlation_id" do
    ingestion = described_class.new

    expect(ingestion).not_to be_valid
    expect(ingestion.errors[:status]).to include("can't be blank")
    expect(ingestion.errors[:correlation_id]).to include("can't be blank")
  end

  it "accepts supported status values" do
    source = FxRateSource.create!(
      name: "Banco Central",
      code: "BCRA",
      source_type: "api",
      version: "v1",
      config: {"base_currency" => "USD", "quote_currency" => "ARS"}
    )

    ingestion = described_class.new(
      source: source,
      status: "success",
      correlation_id: SecureRandom.uuid
    )

    expect(ingestion).to be_valid
  end
end
