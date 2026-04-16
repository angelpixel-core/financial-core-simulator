require "rails_helper"

RSpec.describe Admin::Fx::Adapters::RateResolverProvider do
  describe "#fetch_rate" do
    it "adapts RateResolver output to the fx provider port payload" do
      FxDailyRate.create!(
        operational_date: Date.new(2026, 3, 30),
        base_currency: "USD",
        quote_currency: "ARS",
        rate: "1200.25",
        source: "manual"
      )

      result = described_class.new.fetch_rate(
        base_currency: "USD",
        quote_currency: "ARS",
        at: Date.new(2026, 3, 30)
      )

      expect(result).to include(
        rate: "1200.25",
        rate_source: "manual",
        rate_missing: false,
        operational_date: Date.new(2026, 3, 30)
      )
    end
  end
end
