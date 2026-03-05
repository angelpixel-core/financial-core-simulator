require "rails_helper"

RSpec.describe Avo::Filters::RunSearchPreset do
  describe "#apply" do
    it "filters failed recent runs preset" do
      failed = Run.create!(status: :failed, input_json: { "schemaVersion" => "1.0" })
      Run.create!(status: :succeeded, input_json: { "schemaVersion" => "1.0" })

      query = described_class.new.apply(nil, Run.all, "failed_recent")

      expect(query).to include(failed)
      expect(query.where.not(id: failed.id).pluck(:status)).not_to include("failed")
    end

    it "filters slow recent runs preset by duration threshold and triage ordering" do
      slow = Run.create!(status: :succeeded, duration_ms: 1500, input_json: { "schemaVersion" => "1.0" })
      slower = Run.create!(status: :succeeded, duration_ms: 1900, input_json: { "schemaVersion" => "1.0" })
      Run.create!(status: :succeeded, duration_ms: 900, input_json: { "schemaVersion" => "1.0" })

      query = described_class.new.apply(nil, Run.all, "slow_recent")

      expect(query).to include(slow, slower)
      expect(query.pluck(:duration_ms).min).to be >= 1000
      expect(query.first.id).to eq(slower.id)
    end

    it "filters unverified recent runs preset" do
      unverified = Run.create!(status: :succeeded, verification_status: :unverified, input_json: { "schemaVersion" => "1.0" })
      mismatch = Run.create!(status: :succeeded, verification_status: :mismatch, input_json: { "schemaVersion" => "1.0" })
      verification_error = Run.create!(status: :succeeded, verification_status: :verification_error, input_json: { "schemaVersion" => "1.0" })
      Run.create!(status: :succeeded, verification_status: :verified, input_json: { "schemaVersion" => "1.0" })

      query = described_class.new.apply(nil, Run.all, "unverified_recent")

      expect(query).to include(unverified, mismatch, verification_error)
      expect(query.pluck(:verification_status).uniq).to contain_exactly("unverified", "mismatch", "verification_error")
    end

    it "exposes triage-oriented preset options" do
      options = described_class.new.options

      expect(options).to include(
        "Failed (recent)" => "failed_recent",
        "Slow runs (recent, >= 1000ms)" => "slow_recent",
        "Verification issues (recent)" => "unverified_recent"
      )
    end
  end
end
