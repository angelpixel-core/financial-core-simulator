require "rails_helper"

RSpec.describe Admin::Runs::RunValidationDiagnostics do
  describe "#call" do
    it "returns loading with no issues for nil run" do
      result = described_class.new.call(run: nil)

      expect(result[:state]).to eq(:loading)
      expect(result[:issues]).to eq([])
      expect(result.dig(:diagnostic, :what_happened)).to be_present
    end

    it "maps validation errors to issues with severity" do
      run = Run.create!(
        status: :failed,
        error_code: Runs::ErrorCodeMapper::VALIDATION_RISK,
        error_message: "Invalid risk model",
        input_json: { "source" => "ingest.alpha" },
        run_uuid: "run-1"
      )

      result = described_class.new.call(run: run)

      expect(result[:state]).to eq(:error)
      expect(result[:issues].size).to eq(1)
      expect(result[:issues].first[:severity]).to eq("error")
      expect(result[:issues].first[:field]).to eq("riskModel")
    end

    it "returns success when run has no validation errors" do
      run = Run.create!(
        status: :succeeded,
        verification_status: :verified,
        run_uuid: "run-2"
      )

      result = described_class.new.call(run: run)

      expect(result[:state]).to eq(:success)
      expect(result[:issues]).to be_empty
    end

    it "returns warning when run failed without validation code" do
      run = Run.create!(
        status: :failed,
        error_code: "ERR_EXECUTION_FAILURE",
        error_message: "Execution failed",
        run_uuid: "run-3"
      )

      result = described_class.new.call(run: run)

      expect(result[:state]).to eq(:warning)
      expect(result[:issues]).to be_empty
    end
  end
end
