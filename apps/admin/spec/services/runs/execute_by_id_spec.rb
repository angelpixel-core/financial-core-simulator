require "rails_helper"

RSpec.describe Runs::ExecuteById do
  it "loads run via repository and delegates to executor" do
    run = Run.create!(status: :queued, input_json: {"schemaVersion" => "1.0", "trades" => []})
    repository = instance_double(Runs::Repositories::ActiveRecord::RunRepository)
    executor = instance_double(Runs::Execute)

    allow(repository).to receive(:find_run).with(run_id: run.id).and_return(run)
    allow(executor).to receive(:call)

    described_class.new(run_repository: repository, executor: executor).call(
      run_id: run.id,
      fee_enabled: false,
      explain: true,
      verbose: false
    )

    expect(executor).to have_received(:call).with(run, fee_enabled: false, explain: true, verbose: false)
  end
end
