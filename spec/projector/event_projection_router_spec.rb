# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Projector::EventProjectionRouter do
  it "returns projection keys for known event types" do
    router = described_class.new

    expect(router.projections_for("RUN_LIFECYCLE_NORMALIZED")).to eq(%w[overview trend])
  end

  it "rejects invalid routes configuration" do
    expect do
      described_class.new(routes: {})
    end.to raise_error(FCS::Error) { |error| expect(error.details).to include(field: "eventProjectionRouter.routes") }
  end

  it "rejects route entries with invalid projection keys" do
    expect do
      described_class.new(routes: {"RUN_LIFECYCLE_NORMALIZED" => [""]})
    end.to raise_error(FCS::Error) { |error| expect(error.details[:field]).to include("eventProjectionRouter.routes") }
  end
end
