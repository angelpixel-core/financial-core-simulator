require 'rails_helper'

RSpec.describe Admin::Runs::Execution::EngineAdapter do
  it 'delegates execution to core application executor' do
    executor = instance_double(FCS::Application::ExecuteRun)
    adapter = described_class.new(executor: executor)
    expected = {
      execution_result: FCS::Contracts::RunExecutionResult.from_hash!(
        json_path: 'tmp/result.json',
        input_hash: 'a' * 64,
        run_id: '123e4567-e89b-5d3a-a456-426614174000',
        schema_version: '1.0',
        valuation_timestamp: '2026-04-15T12:00:00Z',
        artifacts: {
          positions_csv_path: 'tmp/positions.csv',
          pnl_csv_path: 'tmp/pnl.csv'
        }
      ),
      duration_ms: 12
    }
    allow(executor).to receive(:call).and_return(expected)

    result = adapter.execute(
      input: { 'schemaVersion' => '1.0', 'trades' => [] },
      output_dir: 'tmp',
      fee_enabled: true,
      explain: true,
      verbose: false
    )

    expect(result).to eq(expected)
    expect(executor).to have_received(:call).with(
      input: { 'schemaVersion' => '1.0', 'trades' => [] },
      output_dir: 'tmp',
      fee_enabled: true,
      explain: true,
      verbose: false
    )
  end
end
