# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Projector::OverviewKpiStatusMixProjector do
  subject(:projector) { described_class.new }

  def lifecycle_event(status, run_id:, correlation_id:)
    {
      "eventVersion" => "1.0",
      "source" => "aggregator.projector",
      "eventType" => "RUN_LIFECYCLE_NORMALIZED",
      "correlationId" => correlation_id,
      "occurredAt" => "2026-03-04T10:00:02Z",
      "payload" => {
        "runId" => run_id,
        "status" => status
      }
    }
  end

  it "projects overview KPI counts from lifecycle events" do
    events = [
      lifecycle_event("queued", run_id: "run-1", correlation_id: "corr-1"),
      lifecycle_event("running", run_id: "run-2", correlation_id: "corr-2"),
      lifecycle_event("succeeded", run_id: "run-3", correlation_id: "corr-3"),
      lifecycle_event("failed", run_id: "run-4", correlation_id: "corr-4")
    ]

    events.each { |event| projector.apply!(event) }

    expect(projector.read_model).to include(
      "overviewKpi" => include(
        "queued" => 1,
        "running" => 1,
        "succeeded" => 1,
        "failed" => 1
      )
    )
  end

  it "projects status mix distribution deterministically" do
    events = [
      lifecycle_event("queued", run_id: "run-1", correlation_id: "corr-1"),
      lifecycle_event("queued", run_id: "run-2", correlation_id: "corr-2"),
      lifecycle_event("failed", run_id: "run-3", correlation_id: "corr-3")
    ]

    events.each { |event| projector.apply!(event) }

    expect(projector.read_model).to include(
      "statusMix" => {
        "queued" => 2,
        "running" => 0,
        "succeeded" => 0,
        "failed" => 1
      }
    )
  end
end
