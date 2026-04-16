# frozen_string_literal: true

module Runs
  module Api
    module_function

    def execute(run:, fee_enabled: true, explain: true, verbose: false)
      Runs::Execute.new.call(run, fee_enabled: fee_enabled, explain: explain, verbose: verbose)
    end

    def execute_by_id(run_id:, fee_enabled: true, explain: true, verbose: false)
      Runs::ExecuteById.new.call(
        run_id: run_id,
        fee_enabled: fee_enabled,
        explain: explain,
        verbose: verbose
      )
    end

    def verify_input_hash(run:)
      Runs::VerifyInputHash.new.call(run)
    end

    def navigation_context(params:, session:)
      Admin::Runs::NavigationContext.new(params: params, session: session).resolve
    end

    def capture_navigation_context(params:, run:)
      Admin::Runs::NavigationContext.capture(params: params, run: run)
    end

    def reliable_selection
      Admin::Runs::ReliableRunSelector.new.call
    end
  end
end
