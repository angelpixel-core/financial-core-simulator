require "rails_helper"

RSpec.describe Avo::Filters::RunInputHash do
  describe "#apply" do
    it "filters runs by partial input hash" do
      matching = Run.create!(status: :succeeded, input_json: { "schemaVersion" => "1.0" }, input_hash: "abc-123")
      Run.create!(status: :succeeded, input_json: { "schemaVersion" => "1.0" }, input_hash: "zzz-999")

      query = described_class.new.apply(nil, Run.all, "abc")

      expect(query).to contain_exactly(matching)
    end

    it "returns original query when value is blank" do
      query = described_class.new.apply(nil, Run.all, "")

      expect(query).to eq(Run.all)
    end
  end
end
