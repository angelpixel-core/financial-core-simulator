require 'rails_helper'

RSpec.describe Runs::Execute do
  let(:run_engine) { instance_double(Admin::Runs::Execution::EngineAdapter) }
  let(:artifact_store) { instance_double(Admin::Runs::Artifacts::FileStoreAdapter) }
  let(:event_bus) { instance_double(Admin::Events::BusAdapter, publish: nil) }
  let(:metrics) { instance_double(Admin::Observability::PrometheusMetricsAdapter, increment: nil, observe: nil) }
  let(:logger) { instance_double(Admin::Observability::StructuredLoggerAdapter, info: nil, error: nil) }
  let(:service) do
    described_class.new(
      run_engine: run_engine,
      artifact_store: artifact_store,
      event_bus: event_bus,
      metrics: metrics,
      logger: logger
    )
  end

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
        input_hash: 'abc123',
        run_id: 'run-123',
        schema_version: '1.0',
        valuation_timestamp: '2026-02-25T03:00:00Z',
        payload: { 'accounts' => [] },
        artifacts: {
          positions_csv_path: File.join(output_dir, 'positions.csv'),
          pnl_csv_path: File.join(output_dir, 'pnl.csv')
        },
        validation_errors: [],
        reliable: true,
        annotated_input: input_json
      )
      artifact_paths = {
        'result_json_path' => nil,
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
      expect(run.result_json_path).to be_nil
      expect(run.positions_csv_path).to eq(File.join(output_dir, 'positions.csv'))
      expect(run.pnl_csv_path).to eq(File.join(output_dir, 'pnl.csv'))
      expect(event_bus).to have_received(:publish).with('runs.execution.completed', hash_including(runId: run.id))
      expect(metrics).to have_received(:increment).with('runs.execution.completed', tags: { status: 'succeeded' })
      expect(metrics).to have_received(:observe).with('runs.execution.duration_ms', value: 42,
                                                                                    tags: { status: 'succeeded' })
      expect(logger).to have_received(:info).with(
        event: 'runs.execution.completed',
        payload: hash_including(runId: run.id, durationMs: 42),
        tags: { status: 'succeeded' }
      )
    end

    it 'marks run as failed when validation errors are present while persisting processed artifacts' do
      run = Run.create!(input_json: input_json)
      output_dir = Rails.root.join('storage', 'runs', 'out_unreliable').to_s
      execution_result = FCS::Contracts::RunExecutionResult.from_hash!(
        input_hash: 'bad123',
        run_id: 'run-bad',
        schema_version: '1.0',
        valuation_timestamp: '2026-02-25T03:00:00Z',
        payload: { 'accounts' => [] },
        artifacts: {
          positions_csv_path: File.join(output_dir, 'positions.csv'),
          pnl_csv_path: File.join(output_dir, 'pnl.csv')
        },
        validation_errors: [{ message: 'invalid trade', code: 'INVALID_TRADE', trade_id: 'trade-1' }],
        reliable: true,
        annotated_input: input_json
      )

      allow(artifact_store).to receive(:build_output_dir).and_return(output_dir)
      allow(run_engine).to receive(:execute).and_return(
        {
          execution_result: execution_result,
          duration_ms: 17
        }
      )
      allow(artifact_store).to receive(:artifact_paths).and_return(
        {
          'result_json_path' => nil,
          'positions_csv_path' => File.join(output_dir, 'positions.csv'),
          'pnl_csv_path' => File.join(output_dir, 'pnl.csv')
        }
      )

      service.call(run)
      run.reload

      expect(run).to be_failed
      expect(run.reliable).to eq(false)
      expect(run.error_code).to eq(Runs::ErrorCodeMapper::VALIDATION_GENERAL)
      expect(run.run_validation_errors.where(code: 'INVALID_TRADE', trade_id: 'trade-1')).to exist
      expect(event_bus).to have_received(:publish).with(
        'runs.execution.failed',
        hash_including(runId: run.id, partial: true, errorCode: Runs::ErrorCodeMapper::VALIDATION_GENERAL)
      )
    end

    it 'keeps succeeded state when artifact persistence is partial (non-reliable until verification)' do
      run = Run.create!(input_json: input_json)
      output_dir = Rails.root.join('storage', 'runs', 'out_partial').to_s
      execution_result = FCS::Contracts::RunExecutionResult.from_hash!(
        input_hash: 'partial123',
        run_id: 'run-partial',
        schema_version: '1.0',
        valuation_timestamp: '2026-02-25T03:00:00Z',
        payload: { 'accounts' => [] },
        artifacts: {
          positions_csv_path: File.join(output_dir, 'positions.csv'),
          pnl_csv_path: File.join(output_dir, 'pnl.csv')
        },
        validation_errors: [],
        reliable: true,
        annotated_input: input_json
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
          'result_json_path' => nil,
          'positions_csv_path' => File.join(output_dir, 'positions.csv'),
          'pnl_csv_path' => nil
        }
      )

      service.call(run)
      run.reload

      expect(run).to be_succeeded
      expect(run.verification_status).to eq('unverified')
      expect(run.result_json_path).to be_nil
      expect(run.positions_csv_path).to eq(File.join(output_dir, 'positions.csv'))
      expect(run.pnl_csv_path).to be_nil
      expect(event_bus).to have_received(:publish).with('runs.execution.completed', hash_including(runId: run.id))
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
      expect(event_bus).to have_received(:publish).with('runs.execution.failed', hash_including(runId: run.id,
                                                                                                errorMessage: 'boom'))
      expect(metrics).to have_received(:increment).with('runs.execution.failed', tags: { status: 'failed' })
      expect(logger).to have_received(:error).with(
        event: 'runs.execution.failed',
        payload: hash_including(runId: run.id, errorMessage: 'boom'),
        tags: hash_including(status: 'failed')
      )
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
      expect(event_bus).to have_received(:publish).with('runs.execution.failed', hash_including(runId: run.id,
                                                                                                errorCode: FCS::Errors::ERR_INVALID_INPUT))
    end
  end
end
