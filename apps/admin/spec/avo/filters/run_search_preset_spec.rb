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
  end
end
