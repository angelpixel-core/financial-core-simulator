# frozen_string_literal: true

module FCS
  module Application
    class ExecuteRun
      def initialize(runner: FCS::Application::Runner.new)
        @runner = runner
      end

      def call(input:, output_dir:, fee_enabled:, explain:, verbose:)
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        result = @runner.run_from_input!(
          input: input,
          output_dir: output_dir,
          fee_enabled: fee_enabled,
          explain: explain,
          verbose: verbose,
          input_source: "run.input_json"
        )

        {
          execution_result: result,
          duration_ms: elapsed_millis(started_at)
        }
      end

      private

      def elapsed_millis(started_at)
        ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).to_i
      end
    end
  end
end
