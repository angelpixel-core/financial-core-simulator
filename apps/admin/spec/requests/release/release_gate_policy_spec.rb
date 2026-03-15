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

    it "returns NO-GO when lint debt is accepted without required metadata" do
      decision = described_class.evaluate(
        gate_type: :pre_production,
        command_results: {
          test_admin: :pass,
          lint_admin: :fail,
          security: :pass
        },
        lint_debt_policy: {
          accepted: true,
          owner: "",
          expiry: nil,
          scope: ""
        }
      )

      expect(decision.fetch(:decision)).to eq("NO-GO")
      expect(decision.fetch(:blockers)).to include("lint_debt_policy_metadata_missing")
    end

    it "returns NO-GO when lint fails and no lint debt policy is provided" do
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

    it "allows accepted lint debt only when owner, expiry, and scope are present" do
      decision = described_class.evaluate(
        gate_type: :pre_production,
        command_results: {
          test_admin: :pass,
          lint_admin: :fail,
          security: :pass
        },
        lint_debt_policy: {
          accepted: true,
          owner: "platform-team",
          expiry: "2026-06-30",
          scope: "apps/admin/db/schema.rb"
        }
      )

      expect(decision.fetch(:decision)).to eq("GO")
      expect(decision.fetch(:blockers)).to eq([])
    end
  end
end
