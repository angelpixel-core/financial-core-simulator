require "rails_helper"

RSpec.describe Admin::Fx::CarryForwardRate do
  around do |example|
    travel_to(Time.zone.parse("2026-03-30 10:00:00")) { example.run }
  end

  it "creates a carry-forward rate when prior day exists" do
    today = Admin::Fx::OperationalDate.call
    FxDailyRate.create!(
      operational_date: today - 1.day,
      base_currency: "USD",
      quote_currency: "ARS",
      rate: "999.5",
      source: "manual"
    )

    rate = described_class.call(
      operational_date: today,
      base_currency: "USD",
      quote_currency: "ARS",
      created_by_id: "bob",
      created_by_role: "operator"
    )

    expect(rate.source).to eq("carry_forward")
    expect(rate.source_rate_id).not_to be_nil
    expect(rate.rate.to_s).to eq("999.5")
  end

  it "rejects carry-forward when no prior rate exists" do
    today = Admin::Fx::OperationalDate.call

    expect do
      described_class.call(
        operational_date: today,
        base_currency: "USD",
        quote_currency: "ARS"
      )
    end.to raise_error(ActiveRecord::RecordInvalid)
  end
end
