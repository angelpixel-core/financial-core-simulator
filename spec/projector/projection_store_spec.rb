# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Projector::ProjectionStore do
  let(:projection) { instance_double("Projection", apply!: true, read_model: { "a" => 1 }) }

  it "applies events to selected projections" do
    store = described_class.new(projections: { "overview" => projection })
    event = { "eventType" => "RUN_LIFECYCLE_NORMALIZED" }

    expect(projection).to receive(:apply!).with(event)
    expect(store.apply!(["overview"], event)).to be(true)
  end

  it "merges read models from all projections" do
    other = instance_double("Projection", apply!: true, read_model: { "b" => 2 })
    store = described_class.new(projections: { "overview" => projection, "trend" => other })

    expect(store.read_model).to eq("a" => 1, "b" => 2)
  end

  it "rejects missing projection keys" do
    store = described_class.new(projections: { "overview" => projection })

    expect do
      store.apply!(["missing"], "event")
    end.to raise_error(FCS::Error) { |error| expect(error.details).to include(field: "projectionStore.projections.missing") }
  end

  it "rejects empty projection keys array" do
    store = described_class.new(projections: { "overview" => projection })

    expect do
      store.apply!([], "event")
    end.to raise_error(FCS::Error) { |error| expect(error.details).to include(field: "projectionStore.projectionKeys") }
  end
end
