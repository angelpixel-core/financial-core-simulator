# frozen_string_literal: true

module Runs
  class Execute
    def initialize(
      run_repository: Runs::Repositories::ActiveRecord::RunRepository.new,
      run_engine: Admin::Runs::Execution::EngineAdapter.new,
      artifact_store: Admin::Runs::Artifacts::FileStoreAdapter.new,
      event_bus: Admin::Events::BusAdapter.new,
      metrics: Admin::Observability::PrometheusMetricsAdapter.new,
      logger: Admin::Observability::StructuredLoggerAdapter.new
    )
      @run_repository = run_repository
      @run_engine = run_engine
      @artifact_store = artifact_store
      @event_bus = event_bus
      @metrics = metrics
      @logger = logger
    end

    def call(run, fee_enabled: true, explain: true, verbose: false)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      @run_repository.save_run!(
        run_id: run.id,
        attributes: { status: :running, error_code: nil, error_message: nil }
      )

      Runs::ApplyFxContext.call(run: run)
      run = @run_repository.find_run(run_id: run.id)

      output_dir = @artifact_store.build_output_dir(run_id: run.id)
      execution = @run_engine.execute(
        input: run.input_json,
        output_dir: output_dir,
        fee_enabled: fee_enabled,
        explain: explain,
        verbose: verbose
      )

      execution_result = execution.fetch(:execution_result)
      duration_ms = execution.fetch(:duration_ms)
      artifact_paths = @artifact_store.artifact_paths(output_dir: output_dir, execution_result: execution_result)

      @run_repository.save_run!(
        run_id: run.id,
        attributes: {
          status: :succeeded,
          engine_version: FCS::VERSION,
          schema_version: execution_result.fetch(:schema_version),
          run_uuid: execution_result.fetch(:run_id),
          input_hash: execution_result.fetch(:input_hash),
          valuation_timestamp: execution_result[:valuation_timestamp],
          output_dir: output_dir,
          artifacts: artifact_paths,
          duration_ms: duration_ms
        }
      )

      publish_success_observability(run: run, duration_ms: duration_ms, artifact_paths: artifact_paths)

      run = @run_repository.find_run(run_id: run.id)

      Runs::PersistDailyArtifacts.call(run: run)
      Admin::Fx::RunRateGapProcessor.call(run: run)

      run
    rescue StandardError => e
      duration_ms = begin
        ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).to_i
      rescue StandardError
        nil
      end
      @run_repository.save_run!(
        run_id: run.id,
        attributes: {
          status: :failed,
          duration_ms: duration_ms,
          error_code: Runs::ErrorCodeMapper.call(e),
          error_message: e.message
        }
      )
      publish_failure_observability(run: run, duration_ms: duration_ms, error: e)
      raise
    end

    private

    def publish_success_observability(run:, duration_ms:, artifact_paths:)
      safe_observe do
        @event_bus.publish('runs.execution.completed', {
                             runId: run.id,
                             status: 'succeeded',
                             durationMs: duration_ms,
                             artifacts: artifact_paths
                           })
      end
      safe_observe do
        @metrics.increment('runs.execution.completed', tags: { status: 'succeeded' })
      end
      safe_observe do
        @metrics.observe('runs.execution.duration_ms', value: duration_ms, tags: { status: 'succeeded' })
      end
      safe_observe do
        @logger.info(
          event: 'runs.execution.completed',
          payload: { runId: run.id, durationMs: duration_ms, artifacts: artifact_paths },
          tags: { status: 'succeeded' }
        )
      end
    end

    def publish_failure_observability(run:, duration_ms:, error:)
      safe_observe do
        @event_bus.publish('runs.execution.failed', {
                             runId: run.id,
                             status: 'failed',
                             durationMs: duration_ms,
                             errorCode: Runs::ErrorCodeMapper.call(error),
                             errorMessage: error.message
                           })
      end
      safe_observe do
        @metrics.increment('runs.execution.failed', tags: { status: 'failed' })
      end
      safe_observe do
        @metrics.observe('runs.execution.duration_ms', value: duration_ms, tags: { status: 'failed' })
      end
      safe_observe do
        @logger.error(
          event: 'runs.execution.failed',
          payload: { runId: run.id, durationMs: duration_ms, errorMessage: error.message },
          tags: { status: 'failed', errorCode: Runs::ErrorCodeMapper.call(error) }
        )
      end
    end

    def safe_observe
      yield
    rescue StandardError
      nil
    end
  end
end
