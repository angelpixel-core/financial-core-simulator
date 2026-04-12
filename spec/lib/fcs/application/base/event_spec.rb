require "spec_helper"
require "fcs/application/base/event"

RSpec.describe FCS::Application::Base::Event do
  it "builds a valid event with allowed type" do
    event = described_class.new(
      event_type: "fx_rate.ingested",
      data: {"count" => 2},
      metadata: {"correlation_id" => "abc"}
    )

    expect(event.event_type).to eq("fx_rate.ingested")
    expect(event.data).to eq({"count" => 2})
    expect(event.metadata).to eq({"correlation_id" => "abc"})
  end

  it "rejects missing event_type" do
    expect {
      described_class.new(event_type: nil)
    }.to raise_error(ArgumentError, "event_type is required")
  end

  it "rejects non-allowed event types" do
    expect {
      described_class.new(event_type: "fx_rate.unknown")
    }.to raise_error(ArgumentError, "event_type is not allowed")
  end
end
