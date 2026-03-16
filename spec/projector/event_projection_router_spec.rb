# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Projector::EventProjectionRouter do
  describe "#projections_for" do
    it "returns projection keys for supported event types" do
      router = described_class.new

      expect(router.projections_for("RUN_LIFECYCLE_NORMALIZED")).to eq(%w[overview trend])
      expect(router.projections_for("ACCOUNT_TOTALS_NORMALIZED")).to eq(["topAccountsRisk"])
      expect(router.projections_for("RISK_SNAPSHOT_NORMALIZED")).to eq(["topAccountsRisk"])
    end

    it "returns nil for unsupported event types" do
      router = described_class.new

      expect(router.projections_for("UNSUPPORTED")).to be_nil
    end
  end

  describe "route validation" do
    it "rejects empty route maps" do
      expect do
        described_class.new(routes: {})
      end.to raise_error(FCS::Error) { |error| expect(error.details).to include(field: "eventProjectionRouter.routes") }
    end
  end
end
