# frozen_string_literal: true

require_relative "../../lib/fcs"
require "date"

RSpec.describe FCS::Projector::ReadModelReplay do
  class StubProjection
    attr_reader :applied, :read_model

    def initialize(read_model)
      @read_model = read_model
      @applied = []
    end

    def apply!(event)
      @applied << event
      true
    end
  end

  class StubProjectionStoreFactory
    attr_reader :calls

    def initialize(read_model)
      @read_model = read_model
      @calls = 0
    end

    def call
      @calls += 1
      FCS::Projector::ProjectionStore.new(projections: { "custom" => StubProjection.new(@read_model) })
    end
  end

  class StubRouter
    def projections_for(event_type)
      return ["custom"] if event_type == "CUSTOM_NORMALIZED"

      nil
    end
  end

  def custom_event
    {
      "eventVersion" => "1.0",
      "source" => "aggregator.projector",
      "eventType" => "CUSTOM_NORMALIZED",
      "correlationId" => "corr-custom",
      "occurredAt" => "2026-03-04T10:00:00Z",
      "payload" => { "runId" => "run-custom" }
    }
  end

  it "routes events through projection store and router interfaces" do
    projection = StubProjection.new("customModel" => { "ok" => true })
    store = FCS::Projector::ProjectionStore.new(projections: { "custom" => projection })

    replay = described_class.new(
      today: Date.new(2026, 3, 4),
      projection_store: store,
      projection_store_factory: -> { store },
      event_projection_router: StubRouter.new
    )

    read_model = replay.apply_stream!([custom_event])

    expect(projection.applied).to eq([custom_event])
    expect(read_model).to eq("customModel" => { "ok" => true })
  end

  it "uses projection store factory when rebuilding from stream" do
    factory = StubProjectionStoreFactory.new("customModel" => { "ok" => true })

    replay = described_class.new(
      today: Date.new(2026, 3, 4),
      projection_store_factory: factory,
      event_projection_router: StubRouter.new
    )

    replay.apply_stream!([custom_event])
    replay.rebuild_from_stream!([custom_event])

    expect(factory.calls).to eq(2)
  end
end
