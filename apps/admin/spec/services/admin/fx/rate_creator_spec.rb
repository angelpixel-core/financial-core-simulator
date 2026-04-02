require "rails_helper"

RSpec.describe Admin::Fx::RateCreator do
  around do |example|
    travel_to(Time.zone.parse("2026-03-30 10:00:00")) { example.run }
  end

  it "creates a manual rate with audit metadata" do
    operational_date = Admin::Fx::OperationalDate.call

    rate = described_class.call(
      operational_date: operational_date,
      base_currency: "USD",
      quote_currency: "ARS",
      rate: "1000.5",
      created_by_id: "alice",
      created_by_role: "operator",
      created_context: {source: "spec"}
    )

    expect(rate).to be_persisted
    expect(rate.source).to eq("manual")
    expect(rate.created_by_id).to eq("alice")
    expect(rate.created_context).to include("source" => "spec")
  end

  it "rejects non-positive rates" do
    operational_date = Admin::Fx::OperationalDate.call

    expect do
      described_class.call(
        operational_date: operational_date,
        base_currency: "USD",
        quote_currency: "ARS",
        rate: "0",
        created_by_id: "alice"
      )
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "rejects mismatched operational dates" do
    expect do
      described_class.call(
        operational_date: Date.new(2026, 3, 29),
        base_currency: "USD",
        quote_currency: "ARS",
        rate: "1000",
        created_by_id: "alice"
      )
    end.to raise_error(ActiveRecord::RecordInvalid)
  end
end
