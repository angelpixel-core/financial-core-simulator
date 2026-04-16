# frozen_string_literal: true

module Runs
  class ExecuteById
    def initialize(
      run_repository: Runs::Repositories::ActiveRecord::RunRepository.new,
      executor: Runs::Execute.new
    )
      @run_repository = run_repository
      @executor = executor
    end

    def call(run_id:, fee_enabled: true, explain: true, verbose: false)
      run = @run_repository.find_run(run_id: run_id)
      @executor.call(run, fee_enabled: fee_enabled, explain: explain, verbose: verbose)
    end
  end
end
