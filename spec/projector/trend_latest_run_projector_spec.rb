# frozen_string_literal: true

require_relative "../../lib/fcs"
require "date"

RSpec.describe FCS::Projector::TrendLatestRunProjector do
  subject(:projector) { described_class.new(today: Date.new(2026, 3, 4)) }

  def lifecycle_event(status, run_id:, correlation_id:, occurred_at:)
    {
      "eventVersion" => "1.0",
      "source" => "aggregator.projector",
      "eventType" => "RUN_LIFECYCLE_NORMALIZED",
      "correlationId" => correlation_id,
      "occurredAt" => occurred_at,
      "payload" => {
        "runId" => run_id,
        "status" => status
      }
    }
  end

  it "projects deterministic 14d trend buckets from lifecycle events" do
    events = [
      lifecycle_event("queued", run_id: "run-1", correlation_id: "corr-1", occurred_at: "2026-03-04T10:00:02Z"),
      lifecycle_event("succeeded", run_id: "run-2", correlation_id: "corr-2", occurred_at: "2026-03-03T12:00:00Z"),
      lifecycle_event("failed", run_id: "run-3", correlation_id: "corr-3", occurred_at: "2026-03-03T13:00:00Z")
    ]

    events.each { |event| projector.apply!(event) }

    read_model = projector.read_model
    trend = read_model.fetch("runsTrend14d")

    expect(trend.length).to eq(14)
    expect(trend.sum { |point| point.fetch("count") }).to eq(3)

    by_day = trend.to_h { |point| [point.fetch("day"), point.fetch("count")] }
    expect(by_day.fetch("03-03")).to eq(2)
    expect(by_day.fetch("03-04")).to eq(1)
  end

  it "projects latest-run traceability using newest occurredAt event" do
    events = [
      lifecycle_event("running", run_id: "run-1", correlation_id: "corr-1", occurred_at: "2026-03-04T09:00:00Z"),
      lifecycle_event("failed", run_id: "run-2", correlation_id: "corr-2", occurred_at: "2026-03-04T10:30:00Z"),
      lifecycle_event("succeeded", run_id: "run-3", correlation_id: "corr-3", occurred_at: "2026-03-04T10:00:00Z")
    ]

    events.each { |event| projector.apply!(event) }

    expect(projector.read_model.fetch("latestRun")).to include(
      "runId" => "run-2",
      "status" => "failed",
      "correlationId" => "corr-2",
      "occurredAt" => "2026-03-04T10:30:00Z"
    )
  end
end
