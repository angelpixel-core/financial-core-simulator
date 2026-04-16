require "rails_helper"

RSpec.describe Admin::Fx::UpdateDailyRate do
  it "updates a manual rate and preserves audit context" do
    rate = FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 30),
      base_currency: "USD",
      quote_currency: "ARS",
      rate: "1000",
      source: "manual",
      created_context: {"source" => "old"}
    )

    described_class.new.call(
      rate_id: rate.id,
      rate: "1100.5",
      created_by_id: 10,
      created_by_role: "operator",
      created_context: {"source" => "admin_overview", "ip" => "127.0.0.1"}
    )

    rate.reload
    expect(rate.rate.to_s).to eq("1100.5")
    expect(rate.source).to eq("manual")
    expect(rate.created_context).to include("source" => "admin_overview", "ip" => "127.0.0.1")
  end

  it "blocks editing non-manual, non-placeholder rates" do
    rate = FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 30),
      base_currency: "USD",
      quote_currency: "ARS",
      rate: "1000",
      source: "upload"
    )

    expect do
      described_class.new.call(
        rate_id: rate.id,
        rate: "1100.5",
        created_by_id: 10,
        created_by_role: "operator",
        created_context: {}
      )
    end.to raise_error(ActiveRecord::RecordInvalid)
  end
end
