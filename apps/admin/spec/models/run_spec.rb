require "rails_helper"

RSpec.describe Run, type: :model do
  describe "defaults" do
    it "sets queued status on create" do
      run = described_class.create!(input_json: {"schemaVersion" => "1.0"})

      expect(run).to be_queued
    end
  end

  describe ".timeline_eligible" do
    it "includes succeeded runs with snapshots and failed runs with validation trace" do
      succeeded_run = described_class.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0"})
      failed_run = described_class.create!(status: :failed, input_json: {"schemaVersion" => "1.0"})
      plain_failed = described_class.create!(status: :failed, input_json: {"schemaVersion" => "1.0"})

      RunSnapshot.create!(run: succeeded_run, operational_date: Date.new(2026, 3, 29), reporting_currency: "USD")
      RunSnapshot.create!(run: failed_run, operational_date: Date.new(2026, 3, 30), reporting_currency: "USD")
      RunValidationError.create!(run: failed_run, message: "invalid", code: "INVALID_SIDE")

      ids = described_class.timeline_eligible.pluck(:id)

      expect(ids).to include(succeeded_run.id, failed_run.id)
      expect(ids).not_to include(plain_failed.id)
    end
  end
end
