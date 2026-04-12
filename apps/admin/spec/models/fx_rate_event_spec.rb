require "rails_helper"
require "securerandom"

RSpec.describe FxRateEvent, type: :model do
  it "requires event_type" do
    event = described_class.new

    expect(event).not_to be_valid
    expect(event.errors[:event_type]).to include("can't be blank")
  end

  it "accepts a valid event record" do
    event = described_class.new(
      event_type: "fx_rate.ingested",
      data: {"records" => 1},
      metadata: {"correlation_id" => SecureRandom.uuid}
    )

    expect(event).to be_valid
  end
end
