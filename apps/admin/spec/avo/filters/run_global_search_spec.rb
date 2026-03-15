require "rails_helper"

RSpec.describe Avo::Filters::RunGlobalSearch do
  describe "#apply" do
    it "searches UUID, input hash and error text" do
      matching = Run.create!(status: :failed, input_json: { "schemaVersion" => "1.0" }, run_uuid: "run-abc", 
input_hash: "hash-1", error_message: "leverage exceeded")
      Run.create!(status: :succeeded, input_json: { "schemaVersion" => "1.0" }, run_uuid: "run-zzz", 
input_hash: "hash-2", error_message: "")

      query = described_class.new.apply(nil, Run.all, "lever")

      expect(query).to contain_exactly(matching)
    end
  end
end
