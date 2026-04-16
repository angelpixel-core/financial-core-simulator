# frozen_string_literal: true

module Runs
  class Execute
    def initialize(
      run_repository: Runs::Repositories::ActiveRecord::RunRepository.new,
      run_engine: Admin::Runs::Execution::EngineAdapter.new,
      artifact_store: Admin::Runs::Artifacts::FileStoreAdapter.new
    )
      @run_repository = run_repository
      @run_engine = run_engine
      @artifact_store = artifact_store
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
      raise
    end
  end
end
