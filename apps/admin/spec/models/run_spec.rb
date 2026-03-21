require "rails_helper"

RSpec.describe Run, type: :model do
  describe "defaults" do
    it "sets queued status on create" do
      run = described_class.create!(input_json: {"schemaVersion" => "1.0"})

      expect(run).to be_queued
    end
  end
end
