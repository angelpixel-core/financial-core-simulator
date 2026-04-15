# frozen_string_literal: true

require "fileutils"

module Runs
  class Execute
    def initialize(
      run_repository: Runs::Adapters::ActiveRecordRunRepository.new,
      run_executor: FCS::Application::ExecuteRun.new
    )
      @run_repository = run_repository
      @run_executor = run_executor
    end

    def call(run, fee_enabled: true, explain: true, verbose: false)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      @run_repository.save_run!(
        run_id: run.id,
        attributes: {status: :running, error_code: nil, error_message: nil}
      )

      Runs::ApplyFxContext.call(run: run)

      output_dir = ensure_output_dir(run)
      execution = @run_executor.call(
        input: run.input_json,
        output_dir: output_dir,
        fee_enabled: fee_enabled,
        explain: explain,
        verbose: verbose
      )

      execution_result = execution.fetch(:execution_result)
      artifacts = execution_result.fetch(:artifacts)
      duration_ms = execution.fetch(:duration_ms)

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
          artifacts: {
            "result_json_path" => execution_result.fetch(:json_path),
            "positions_csv_path" => artifacts.fetch(:positions_csv_path),
            "pnl_csv_path" => artifacts.fetch(:pnl_csv_path)
          },
          duration_ms: duration_ms
        }
      )

      run = @run_repository.find_run(run_id: run.id)

      Runs::PersistDailyArtifacts.call(run: run)
      Admin::Fx::RunRateGapProcessor.call(run: run)

      run
    rescue => e
      duration_ms = begin
        ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).to_i
      rescue
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

    private

    def ensure_output_dir(run)
      base = Rails.root.join("storage", "runs")
      FileUtils.mkdir_p(base)

      dir = base.join("run_#{run.id}_#{Time.now.utc.strftime("%Y%m%dT%H%M%S")}")
      FileUtils.mkdir_p(dir)
      dir.to_s
    end
  end
end
