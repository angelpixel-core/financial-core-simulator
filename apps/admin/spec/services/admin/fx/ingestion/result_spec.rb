require "rails_helper"

RSpec.describe FCS::Application::Base::Result do
  describe ".success" do
    it "builds a successful result with data and metadata" do
      result = described_class.success(data: {"rates" => 2}, metadata: {"source" => "BCRA"})

      expect(result).to be_success
      expect(result).not_to be_failure
      expect(result.data).to eq({"rates" => 2})
      expect(result.metadata).to eq({"source" => "BCRA"})
      expect(result.error_code).to be_nil
      expect(result.context).to eq({})
    end
  end

  describe ".failure" do
    it "builds a failed result with error context" do
      result = described_class.failure(
        error_code: "validation_failed",
        context: {"field" => "fecha"},
        metadata: {"correlation_id" => "abc"}
      )

      expect(result).to be_failure
      expect(result).not_to be_success
      expect(result.error_code).to eq("validation_failed")
      expect(result.context).to eq({"field" => "fecha"})
      expect(result.metadata).to eq({"correlation_id" => "abc"})
      expect(result.data).to eq({})
    end

    it "requires an error_code" do
      expect {
        described_class.failure(error_code: nil)
      }.to raise_error(ArgumentError, "error_code is required")
    end
  end
end
