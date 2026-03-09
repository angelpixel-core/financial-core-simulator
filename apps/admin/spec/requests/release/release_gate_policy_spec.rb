require "rails_helper"

RSpec.describe Release::GateDecision do
  describe ".evaluate" do
    it "returns GO for pre-demo when mandatory command results pass" do
      decision = described_class.evaluate(
        gate_type: :pre_demo,
        command_results: {
          test_admin: :pass,
          lint_admin: :pass,
          security: :pass
        }
      )

      expect(decision.fetch(:decision)).to eq("GO")
      expect(decision.fetch(:blockers)).to eq([])
    end

    it "returns NO-GO for pre-production when any mandatory result fails" do
      decision = described_class.evaluate(
        gate_type: :pre_production,
        command_results: {
          test_admin: :pass,
          lint_admin: :fail,
          security: :pass
        }
      )

      expect(decision.fetch(:decision)).to eq("NO-GO")
      expect(decision.fetch(:blockers)).to include("lint_admin")
    end
  end
end
