require "rails_helper"

RSpec.describe Runs::Execute do
  let(:run_executor) { instance_double(FCS::Application::ExecuteRun) }
  let(:service) { described_class.new(run_executor: run_executor) }

  let(:input_json) do
    {
      "schemaVersion" => "1.0",
      "accounts" => [{"accountId" => "acc-1"}],
      "markets" => [{"marketId" => "ETH-USD"}],
      "feeModel" => {"enabled" => true},
      "trades" => [],
      "priceSnapshot" => {
        "valuationTimestamp" => "2026-02-25T03:00:00Z",
        "prices" => [{"marketId" => "ETH-USD", "priceQuotePerBase" => "150"}]
      }
    }
  end

  describe "#call" do
    it "marks run as succeeded and persists metadata + artifact paths" do
      run = Run.create!(input_json: input_json)
      output_dir = Rails.root.join("storage", "runs", "out_run").to_s

      expect(Admin::Fx::RunRateGapProcessor).to receive(:call).with(run: run)
      allow(service).to receive(:ensure_output_dir).and_return(output_dir)
      allow(run_executor).to receive(:call).and_return(
        {
          execution_result: FCS::Contracts::RunExecutionResult.from_hash!(
            json_path: File.join(output_dir, "result.json"),
            input_hash: "abc123",
            run_id: "run-123",
            schema_version: "1.0",
            valuation_timestamp: "2026-02-25T03:00:00Z",
            artifacts: {
              positions_csv_path: File.join(output_dir, "positions.csv"),
              pnl_csv_path: File.join(output_dir, "pnl.csv")
            }
          ),
          duration_ms: 42
        }
      )

      service.call(run)
      run.reload

      expect(run).to be_succeeded
      expect(run.engine_version).to eq(FCS::VERSION)
      expect(run.schema_version).to eq("1.0")
      expect(run.run_uuid).to eq("run-123")
      expect(run.input_hash).to eq("abc123")
      expect(run.valuation_timestamp).to eq(Time.zone.parse("2026-02-25T03:00:00Z"))
      expect(run.duration_ms).to eq(42)
      expect(run.result_json_path).to end_with("result.json")
      expect(run.positions_csv_path).to end_with("positions.csv")
      expect(run.pnl_csv_path).to end_with("pnl.csv")
    end

    it "marks run as failed with error metadata when runner raises" do
      run = Run.create!(input_json: input_json)

      expect(Admin::Fx::RunRateGapProcessor).not_to receive(:call)

      allow(run_executor).to receive(:call).and_raise(StandardError, "boom")

      expect { service.call(run) }.to raise_error(StandardError, "boom")

      run.reload
      expect(run).to be_failed
      expect(run.error_code).to eq("ERR_EXECUTION_FAILURE")
      expect(run.error_message).to eq("boom")
      expect(run.duration_ms).not_to be_nil
    end

    it "maps FCS::Error code when runner raises domain error" do
      run = Run.create!(input_json: input_json)

      allow(run_executor).to receive(:call).and_raise(FCS::Error.new(FCS::Errors::ERR_INVALID_INPUT, "invalid input"))

      expect { service.call(run) }.to raise_error(FCS::Error)

      run.reload
      expect(run).to be_failed
      expect(run.error_code).to eq(FCS::Errors::ERR_INVALID_INPUT)
      expect(run.error_message).to eq("invalid input")
    end
  end
end
