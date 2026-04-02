require "rails_helper"

RSpec.describe Admin::Fx::OperationalDate do
  it "uses the provided timezone to resolve the operational date" do
    timestamp = Time.utc(2026, 3, 30, 2, 0, 0)

    date = described_class.call(timestamp: timestamp, timezone: "America/Argentina/Buenos_Aires")

    expect(date).to eq(Date.new(2026, 3, 29))
  end

  it "uses the timestamp override when provided" do
    date = described_class.call(timestamp: "2026-03-30T03:00:00Z", timezone: "UTC")

    expect(date).to eq(Date.new(2026, 3, 30))
  end
end
