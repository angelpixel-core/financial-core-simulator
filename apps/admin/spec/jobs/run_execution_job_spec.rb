require 'rails_helper'

RSpec.describe RunExecutionJob, type: :job do
  it 'delegates execution to Runs::ExecuteById with default flags' do
    run = Run.create!(status: :queued, input_json: { 'schemaVersion' => '1.0' })

    service = instance_double(Runs::ExecuteById)
    allow(Runs::ExecuteById).to receive(:new).and_return(service)
    expect(service).to receive(:call).with(run_id: run.id, fee_enabled: true, explain: true, verbose: false)

    described_class.perform_now(run.id)
  end
end
