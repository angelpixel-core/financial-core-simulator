class RunExecutionJob < ApplicationJob
  queue_as :default

  def perform(run_id, fee_enabled: true, explain: true, verbose: false)
    run = Run.find(run_id)
    Runs::Execute.new.call(run, fee_enabled: fee_enabled, explain: explain, verbose: verbose)
  end
end
