# frozen_string_literal: true

module Admin
  module Runs
    module Execution
      class EngineAdapter
        def initialize(executor: FCS::Application::ExecuteRun.new)
          @executor = executor
        end

        def execute(input:, output_dir:, fee_enabled:, explain:, verbose:)
          @executor.call(
            input: input,
            output_dir: output_dir,
            fee_enabled: fee_enabled,
            explain: explain,
            verbose: verbose
          )
        end
      end
    end
  end
end
