require "rails_helper"

RSpec.describe Admin::Runs::ReliableRunSelector do
  describe "#call" do
    it "selects the latest verified succeeded run as reliable" do
      Run.create!(status: :succeeded, verification_status: :verified)
      latest_verified = Run.create!(status: :succeeded, verification_status: :verified)

      result = described_class.new.call

      expect(result.reliable_run).to eq(latest_verified)
      expect(result.state).to eq(:reliable)
      expect(result.candidate_run).to eq(latest_verified)
    end

    it "falls back to degraded state when no verified run exists" do
      latest_success = Run.create!(status: :succeeded, verification_status: :unverified)

      result = described_class.new.call

      expect(result.reliable_run).to be_nil
      expect(result.state).to eq(:degraded)
      expect(result.candidate_run).to eq(latest_success)
      expect(result.diagnostic[:what_happened]).to be_present
      expect(result.diagnostic[:impact]).to be_present
      expect(result.diagnostic[:next_action]).to be_present
    end

    it "returns non reliable degraded state when latest successful run is marked unreliable" do
      reliable = Run.create!(status: :succeeded, verification_status: :verified, reliable: true)
      latest_non_reliable = Run.create!(status: :succeeded, verification_status: :verified, reliable: false)

      result = described_class.new.call

      expect(result.reliable_run).to be_nil
      expect(result.state).to eq(:degraded)
      expect(result.candidate_run).to eq(latest_non_reliable)
      expect(result.candidate_run).not_to eq(reliable)
      expect(result.diagnostic[:what_happened]).to include("run")
    end

    it "returns degraded state when latest run failed with validation trace" do
      Run.create!(status: :succeeded, verification_status: :verified, reliable: true)
      latest_failed = Run.create!(status: :failed, verification_status: :unverified, reliable: false)
      RunValidationError.create!(run: latest_failed, message: "INVALID_SIDE", code: "INVALID_SIDE")

      result = described_class.new.call

      expect(result.reliable_run).to be_nil
      expect(result.state).to eq(:degraded)
      expect(result.candidate_run).to eq(latest_failed)
    end

    it "returns empty degraded state when no runs exist" do
      result = described_class.new.call

      expect(result.reliable_run).to be_nil
      expect(result.candidate_run).to be_nil
      expect(result.state).to eq(:degraded)
      expect(result.diagnostic[:what_happened]).to be_present
      expect(result.diagnostic[:impact]).to be_present
      expect(result.diagnostic[:next_action]).to be_present
    end
  end
end
