# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Projector::OverviewKpiStatusMixProjector do
  it "tracks status counts per run" do
    projector = described_class.new

    projector.apply!(
      "eventType" => "RUN_LIFECYCLE_NORMALIZED",
      "payload" => {"runId" => "run-1", "status" => "queued"}
    )
    projector.apply!(
      "eventType" => "RUN_LIFECYCLE_NORMALIZED",
      "payload" => {"runId" => "run-1", "status" => "running"}
    )
    projector.apply!(
      "eventType" => "RUN_LIFECYCLE_NORMALIZED",
      "payload" => {"runId" => "run-2", "status" => "failed"}
    )

    model = projector.read_model

    expect(model.fetch("statusMix")).to include(
      "queued" => 0,
      "running" => 1,
      "succeeded" => 0,
      "failed" => 1
    )
  end

  it "rejects unsupported statuses" do
    projector = described_class.new

    expect do
      projector.apply!(
        "eventType" => "RUN_LIFECYCLE_NORMALIZED",
        "payload" => {"runId" => "run-1", "status" => "unknown"}
      )
    end.to raise_error(FCS::Error) { |error| expect(error.details).to include(field: "event.payload.status") }
  end
end
