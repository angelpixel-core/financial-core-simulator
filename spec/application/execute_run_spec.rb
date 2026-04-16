# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Application::ExecuteRun do
  it "delegates to runner and returns execution result with duration" do
    runner = instance_double(FCS::Application::Runner)
    run_result = FCS::Contracts::RunExecutionResult.from_hash!(
      json_path: "tmp/result.json",
      input_hash: "a" * 64,
      run_id: "123e4567-e89b-5d3a-a456-426614174000",
      schema_version: "1.0",
      valuation_timestamp: "2026-04-15T12:00:00Z",
      artifacts: {
        json_path: "tmp/result.json",
        positions_csv_path: "tmp/positions.csv",
        pnl_csv_path: "tmp/pnl.csv"
      }
    )
    allow(runner).to receive(:run_from_input!).and_return(run_result)

    result = described_class.new(runner: runner).call(
      input: {"schemaVersion" => "1.0", "trades" => []},
      output_dir: "tmp",
      fee_enabled: true,
      explain: true,
      verbose: false
    )

    expect(result.fetch(:execution_result)).to eq(run_result)
    expect(result.fetch(:duration_ms)).to be >= 0
  end
end
