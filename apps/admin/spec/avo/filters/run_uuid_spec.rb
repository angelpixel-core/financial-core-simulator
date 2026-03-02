require "rails_helper"

RSpec.describe Avo::Filters::RunUuid do
  describe "#apply" do
    it "filters runs by partial run UUID" do
      matching = Run.create!(status: :succeeded, input_json: { "schemaVersion" => "1.0" }, run_uuid: "run-abc")
      Run.create!(status: :succeeded, input_json: { "schemaVersion" => "1.0" }, run_uuid: "run-zzz")

      query = described_class.new.apply(nil, Run.all, "abc")

      expect(query).to contain_exactly(matching)
    end

    it "returns original query when value is blank" do
      query = described_class.new.apply(nil, Run.all, "")

      expect(query).to eq(Run.all)
    end
  end
end
