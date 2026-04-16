require 'rails_helper'

RSpec.describe Runs::Execute do
  let(:run_engine) { instance_double(Admin::Runs::Execution::EngineAdapter) }
  let(:artifact_store) { instance_double(Admin::Runs::Artifacts::FileStoreAdapter) }
  let(:service) { described_class.new(run_engine: run_engine, artifact_store: artifact_store) }

  let(:input_json) do
    {
      'schemaVersion' => '1.0',
      'accounts' => [{ 'accountId' => 'acc-1' }],
      'markets' => [{ 'marketId' => 'ETH-USD' }],
      'feeModel' => { 'enabled' => true },
      'trades' => [],
      'priceSnapshot' => {
        'valuationTimestamp' => '2026-02-25T03:00:00Z',
        'prices' => [{ 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '150' }]
      }
    }
  end

  describe '#call' do
    it 'marks run as succeeded and persists metadata + artifact paths' do
      run = Run.create!(input_json: input_json)
      output_dir = Rails.root.join('storage', 'runs', 'out_run').to_s
      execution_result = FCS::Contracts::RunExecutionResult.from_hash!(
        json_path: File.join(output_dir, 'result.json'),
        input_hash: 'abc123',
        run_id: 'run-123',
        schema_version: '1.0',
        valuation_timestamp: '2026-02-25T03:00:00Z',
        artifacts: {
          positions_csv_path: File.join(output_dir, 'positions.csv'),
          pnl_csv_path: File.join(output_dir, 'pnl.csv')
        }
      )
      artifact_paths = {
        'result_json_path' => File.join(output_dir, 'result.json'),
        'positions_csv_path' => File.join(output_dir, 'positions.csv'),
        'pnl_csv_path' => File.join(output_dir, 'pnl.csv')
      }

      expect(Admin::Fx::RunRateGapProcessor).to receive(:call).with(run: run)
      allow(artifact_store).to receive(:build_output_dir).and_return(output_dir)
      allow(run_engine).to receive(:execute).and_return(
        {
          execution_result: execution_result,
          duration_ms: 42
        }
      )
      allow(artifact_store).to receive(:artifact_paths).and_return(artifact_paths)

      service.call(run)
      run.reload

      expect(run).to be_succeeded
      expect(run.engine_version).to eq(FCS::VERSION)
      expect(run.schema_version).to eq('1.0')
      expect(run.run_uuid).to eq('run-123')
      expect(run.input_hash).to eq('abc123')
      expect(run.valuation_timestamp).to eq(Time.zone.parse('2026-02-25T03:00:00Z'))
      expect(run.duration_ms).to eq(42)
      expect(run.result_json_path).to eq(File.join(output_dir, 'result.json'))
      expect(run.positions_csv_path).to eq(File.join(output_dir, 'positions.csv'))
      expect(run.pnl_csv_path).to eq(File.join(output_dir, 'pnl.csv'))
    end

    it 'keeps succeeded state when artifact persistence is partial (non-reliable until verification)' do
      run = Run.create!(input_json: input_json)
      output_dir = Rails.root.join('storage', 'runs', 'out_partial').to_s
      execution_result = FCS::Contracts::RunExecutionResult.from_hash!(
        json_path: File.join(output_dir, 'result.json'),
        input_hash: 'partial123',
        run_id: 'run-partial',
        schema_version: '1.0',
        valuation_timestamp: '2026-02-25T03:00:00Z',
        artifacts: {
          positions_csv_path: File.join(output_dir, 'positions.csv'),
          pnl_csv_path: File.join(output_dir, 'pnl.csv')
        }
      )

      allow(artifact_store).to receive(:build_output_dir).and_return(output_dir)
      allow(run_engine).to receive(:execute).and_return(
        {
          execution_result: execution_result,
          duration_ms: 25
        }
      )
      allow(artifact_store).to receive(:artifact_paths).and_return(
        {
          'result_json_path' => File.join(output_dir, 'result.json'),
          'positions_csv_path' => File.join(output_dir, 'positions.csv'),
          'pnl_csv_path' => nil
        }
      )

      service.call(run)
      run.reload

      expect(run).to be_succeeded
      expect(run.verification_status).to eq('unverified')
      expect(run.result_json_path).to eq(File.join(output_dir, 'result.json'))
      expect(run.positions_csv_path).to eq(File.join(output_dir, 'positions.csv'))
      expect(run.pnl_csv_path).to be_nil
    end

    it 'marks run as failed with error metadata when runner raises' do
      run = Run.create!(input_json: input_json)
      allow(artifact_store).to receive(:build_output_dir).and_return(Rails.root.join('storage', 'runs',
                                                                                     'out_error').to_s)

      expect(Admin::Fx::RunRateGapProcessor).not_to receive(:call)

      allow(run_engine).to receive(:execute).and_raise(StandardError, 'boom')

      expect { service.call(run) }.to raise_error(StandardError, 'boom')

      run.reload
      expect(run).to be_failed
      expect(run.error_code).to eq('ERR_EXECUTION_FAILURE')
      expect(run.error_message).to eq('boom')
      expect(run.duration_ms).not_to be_nil
    end

    it 'maps FCS::Error code when runner raises domain error' do
      run = Run.create!(input_json: input_json)
      allow(artifact_store).to receive(:build_output_dir).and_return(Rails.root.join('storage', 'runs',
                                                                                     'out_domain_error').to_s)

      allow(run_engine).to receive(:execute)
        .and_raise(FCS::Error.new(FCS::Errors::ERR_INVALID_INPUT, 'invalid input'))

      expect { service.call(run) }.to raise_error(FCS::Error)

      run.reload
      expect(run).to be_failed
      expect(run.error_code).to eq(FCS::Errors::ERR_INVALID_INPUT)
      expect(run.error_message).to eq('invalid input')
    end
  end
end
