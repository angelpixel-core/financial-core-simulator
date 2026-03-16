# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Ingestion::SourceEventValidator do
  let(:validator) { described_class.new }

  def valid_event
    {
      "eventVersion" => "1.0",
      "source" => "venue.binance",
      "eventType" => "ORDER_FILLED",
      "correlationId" => "corr-1",
      "occurredAt" => "2026-02-25T03:00:00Z",
      "payload" => { "marketId" => "ETH-USD" }
    }
  end

  it "accepts a valid source event" do
    expect(validator.validate!(valid_event)).to be(true)
  end

  it "rejects non-hash event payloads" do
    expect do
      validator.validate!("nope")
    end.to raise_error(FCS::Error) { |error| expect(error.details).to include(field: "sourceEvent") }
  end

  it "rejects missing required fields" do
    event = valid_event.dup
    event.delete("eventType")

    expect do
      validator.validate!(event)
    end.to raise_error(FCS::Error) { |error| expect(error.details).to include(field: "sourceEvent.eventType") }
  end

  it "rejects blank string fields" do
    event = valid_event.merge("source" => " ")

    expect do
      validator.validate!(event)
    end.to raise_error(FCS::Error) { |error| expect(error.details).to include(field: "sourceEvent.source") }
  end

  it "rejects non-hash payloads" do
    event = valid_event.merge("payload" => "oops")

    expect do
      validator.validate!(event)
    end.to raise_error(FCS::Error) { |error| expect(error.details).to include(field: "sourceEvent.payload") }
  end

  it "classifies duplicates with idempotency guard" do
    events = [valid_event, valid_event.merge("eventVersion" => "1.1")]

    result = validator.validate_batch!(events)

    expect(result.fetch(:accepted).size).to eq(1)
    expect(result.fetch(:duplicates).size).to eq(1)
  end
end
