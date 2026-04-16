require "rails_helper"

RSpec.describe Admin::Runs::ValidationErrors::Repository do
  subject(:repository) { described_class.new }

  describe "#validation_error?" do
    it "returns true for known validation error codes" do
      run = Run.new(error_code: Runs::ErrorCodeMapper::VALIDATION_ACCOUNTING)

      expect(repository.validation_error?(run: run)).to be(true)
    end

    it "returns false for unknown codes and nil runs" do
      run = Run.new(error_code: "ERR_EXECUTION_FAILURE")

      expect(repository.validation_error?(run: run)).to be(false)
      expect(repository.validation_error?(run: nil)).to be(false)
    end
  end

  describe "#issues_for" do
    it "returns mapped issue with severity when run is validation error" do
      run = Run.create!(
        status: :failed,
        error_code: Runs::ErrorCodeMapper::VALIDATION_RISK,
        error_message: "Invalid risk model",
        input_json: {"source" => "ingest.alpha"},
        run_uuid: "run-validation-repo-1"
      )

      issues = repository.issues_for(run: run)

      expect(issues.size).to eq(1)
      expect(issues.first[:severity]).to eq("error")
      expect(issues.first[:field]).to eq("riskModel")
    end

    it "returns empty array for non-validation errors" do
      run = Run.new(error_code: "ERR_EXECUTION_FAILURE")

      expect(repository.issues_for(run: run)).to eq([])
    end
  end
end
