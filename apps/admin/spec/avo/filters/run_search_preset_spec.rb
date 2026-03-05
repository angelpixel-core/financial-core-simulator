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
      Run.create!(status: :succeeded, verification_status: :verified, input_json: { "schemaVersion" => "1.0" })

      query = described_class.new.apply(nil, Run.all, "unverified_recent")

      expect(query).to include(unverified)
      expect(query.where.not(id: unverified.id).pluck(:verification_status)).not_to include("unverified")
    end
  end
end
