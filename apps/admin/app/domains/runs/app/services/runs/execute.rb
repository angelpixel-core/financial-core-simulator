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
      annotated_input = execution_result.fetch(:annotated_input, run.input_json)
      validation_errors = Array(execution_result[:validation_errors])
      reliable = execution_result.fetch(:reliable, true)
      reliable = false if validation_errors.present?
      validation_failed = validation_errors.present?
      failure_error_code = Runs::ErrorCodeMapper::VALIDATION_GENERAL
      failure_message = 'Run completed with validation errors'
      artifact_paths = @artifact_store.artifact_paths(output_dir: output_dir, execution_result: execution_result)

      @run_repository.save_run!(
        run_id: run.id,
        attributes: {
          status: validation_failed ? :failed : :succeeded,
          engine_version: FCS::VERSION,
          schema_version: execution_result.fetch(:schema_version),
          run_uuid: execution_result.fetch(:run_id),
          input_hash: execution_result.fetch(:input_hash),
          input_json: annotated_input,
          valuation_timestamp: execution_result[:valuation_timestamp],
          output_dir: output_dir,
          reliable: reliable,
          artifacts: artifact_paths,
          duration_ms: duration_ms,
          error_code: validation_failed ? failure_error_code : nil,
          error_message: validation_failed ? failure_message : nil
        }
      )

      persist_validation_errors(run, validation_errors, annotated_input)

      if validation_failed
        publish_failure_observability(
          run: run,
          duration_ms: duration_ms,
          error_code: failure_error_code,
          error_message: failure_message,
          partial: true
        )
      else
        publish_success_observability(run: run, duration_ms: duration_ms, artifact_paths: artifact_paths)
      end

      run = @run_repository.find_run(run_id: run.id)
      Runs::PersistDailyArtifacts.call(run: run, payload: execution_result[:payload])
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

    def publish_failure_observability(run:, duration_ms:, error: nil, error_code: nil, error_message: nil,
                                      partial: false)
      resolved_error_code = error_code || Runs::ErrorCodeMapper.call(error)
      resolved_error_message = error_message || error&.message

      safe_observe do
        @event_bus.publish('runs.execution.failed', {
                             runId: run.id,
                             status: 'failed',
                             durationMs: duration_ms,
                             errorCode: resolved_error_code,
                             errorMessage: resolved_error_message,
                             partial: partial
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
          payload: { runId: run.id, durationMs: duration_ms, errorMessage: resolved_error_message, partial: partial },
          tags: { status: 'failed', errorCode: resolved_error_code }
        )
      end
    end

    def safe_observe
      yield
    rescue StandardError
      nil
    end

    def persist_validation_errors(run, validation_errors, input)
      run.run_validation_errors.delete_all
      return if validation_errors.blank?

      correlation_id = input.is_a?(Hash) ? (input['correlationId'] || run.run_uuid) : run.run_uuid
      now = Time.current

      entries = validation_errors.map do |error|
        {
          run_id: run.id,
          source: error[:source],
          field: error[:field],
          message: error[:message].to_s,
          code: error[:code],
          trade_id: error[:trade_id],
          account_id: error[:account_id],
          market_id: error[:market_id],
          timeline_seq: error[:timeline_seq],
          event_type: error[:event_type],
          row_index: error[:row_index],
          occurred_at: parse_occurred_at(error[:occurred_at]),
          correlation_id: correlation_id,
          created_at: now,
          updated_at: now
        }
      end

      RunValidationError.insert_all(entries)
    end

    def parse_occurred_at(value)
      return nil if value.blank?
      return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
