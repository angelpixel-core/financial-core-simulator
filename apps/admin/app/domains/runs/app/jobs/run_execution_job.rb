class RunExecutionJob < ApplicationJob
  queue_as :default

  def perform(run_id, fee_enabled: true, explain: true, verbose: false)
    Runs::Api.execute_by_id(
      run_id: run_id,
      fee_enabled: fee_enabled,
      explain: explain,
      verbose: verbose
    )
  end
end
