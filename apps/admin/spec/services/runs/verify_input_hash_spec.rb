require "rails_helper"

RSpec.describe Runs::VerifyInputHash do
  describe "#call" do
    it "marks run as verified when recomputed hash matches" do
      input = {
        "schemaVersion" => "1.0",
        "trades" => [ { "timestamp" => "2026-01-01T00:00:00Z", "seq" => 1 } ],
        "feeModel" => { "enabled" => true }
      }
      normalized = described_class.new.send(:normalize_input, input)
      canonical = FCS::Hashing::CanonicalJSON.dump(normalized)
      hash = FCS::Hashing::SHA256.hex(canonical)

      run = Run.create!(status: :succeeded, input_json: input, input_hash: hash)

      result = described_class.new.call(run)
      run.reload

      expect(result[:status]).to eq("verified")
      expect(run).to be_verified
      expect(run.verified_at).not_to be_nil
      expect(run.verification_input_hash).to eq(hash)
      expect(run.verification_error).to be_nil
    end

    it "marks run as mismatch when recomputed hash differs" do
      input = {
        "schemaVersion" => "1.0",
        "trades" => [ { "timestamp" => "2026-01-01T00:00:00Z", "seq" => 1 } ],
        "feeModel" => { "enabled" => true }
      }
      normalized = described_class.new.send(:normalize_input, input)
      canonical = FCS::Hashing::CanonicalJSON.dump(normalized)
      hash = FCS::Hashing::SHA256.hex(canonical)
      run = Run.create!(status: :succeeded, input_json: input, input_hash: "#{hash}-different")

      result = described_class.new.call(run)
      run.reload

      expect(result[:status]).to eq("mismatch")
      expect(run).to be_mismatch
      expect(run.verified_at).not_to be_nil
      expect(run.verification_error).to be_nil
    end

    it "marks verification_error when required input is missing" do
      run = Run.create!(status: :succeeded, input_json: nil, input_hash: nil)

      result = described_class.new.call(run)
      run.reload

      expect(result[:status]).to eq("verification_error")
      expect(run).to be_verification_error
      expect(run.verification_error).to include("Run#input_json is required")
    end
  end
end
