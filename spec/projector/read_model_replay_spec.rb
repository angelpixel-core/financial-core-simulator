# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Projector::ReadModelReplay do
  it "applies event stream and returns read model" do
    instance_double("Projection", apply!: true, read_model: { "kpi" => {} })
    store = instance_double("ProjectionStore", apply!: true, read_model: { "kpi" => {} })
    router = instance_double(FCS::Projector::EventProjectionRouter, projections_for: ["overview"])

    replay = described_class.new(
      projection_store: store,
      event_projection_router: router,
      projection_store_factory: instance_double("StoreFactory", call: store)
    )

    events = [{ "eventType" => "RUN_LIFECYCLE_NORMALIZED" }]

    expect(store).to receive(:apply!).with(["overview"], events.first)
    expect(replay.apply_stream!(events)).to eq("kpi" => {})
  end

  it "rejects unsupported event types" do
    store = instance_double("ProjectionStore", apply!: true, read_model: {})
    router = instance_double(FCS::Projector::EventProjectionRouter, projections_for: nil)

    replay = described_class.new(
      projection_store: store,
      event_projection_router: router,
      projection_store_factory: instance_double("StoreFactory", call: store)
    )

    expect do
      replay.apply_stream!([{ "eventType" => "UNKNOWN" }])
    end.to raise_error(FCS::Error) { |error| expect(error.details).to include(field: "event.eventType") }
  end

  it "rejects invalid projection store interfaces" do
    expect do
      described_class.new(
        projection_store: Object.new,
        event_projection_router: instance_double(FCS::Projector::EventProjectionRouter, projections_for: []),
        projection_store_factory: instance_double("StoreFactory", call: Object.new)
      )
    end.to raise_error(FCS::Error) { |error| expect(error.details).to include(field: "projectionStore") }
  end
end
