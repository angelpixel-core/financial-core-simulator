# frozen_string_literal: true

require_relative "../../lib/fcs"
require "date"

RSpec.describe FCS::Projector::TrendLatestRunProjector do
  it "tracks latest run and 14-day trend" do
    today = Date.new(2026, 2, 25)
    projector = described_class.new(today: today)

    projector.apply!(
      "eventType" => "RUN_LIFECYCLE_NORMALIZED",
      "correlationId" => "corr-1",
      "occurredAt" => "2026-02-20T12:00:00Z",
      "payload" => { "runId" => "run-1", "status" => "queued" }
    )

    projector.apply!(
      "eventType" => "RUN_LIFECYCLE_NORMALIZED",
      "correlationId" => "corr-2",
      "occurredAt" => "2026-02-25T12:00:00Z",
      "payload" => { "runId" => "run-2", "status" => "succeeded" }
    )

    model = projector.read_model

    expect(model.fetch("latestRun")).to include("runId" => "run-2", "status" => "succeeded")
    expect(model.fetch("runsTrend14d").size).to eq(14)
  end

  it "rejects invalid occurredAt" do
    projector = described_class.new(today: Date.new(2026, 2, 25))

    expect do
      projector.apply!(
        "eventType" => "RUN_LIFECYCLE_NORMALIZED",
        "correlationId" => "corr-1",
        "occurredAt" => "bad",
        "payload" => { "runId" => "run-1", "status" => "queued" }
      )
    end.to raise_error(FCS::Error) { |error| expect(error.details).to include(field: "event.occurredAt") }
  end
end
