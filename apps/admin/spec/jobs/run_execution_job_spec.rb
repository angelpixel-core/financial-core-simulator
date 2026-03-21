require "rails_helper"

RSpec.describe RunExecutionJob, type: :job do
  it "delegates execution to Runs::Execute with default flags" do
    run = Run.create!(status: :queued, input_json: {"schemaVersion" => "1.0"})

    service = instance_double(Runs::Execute)
    allow(Runs::Execute).to receive(:new).and_return(service)
    expect(service).to receive(:call).with(run, fee_enabled: true, explain: true, verbose: false)

    described_class.perform_now(run.id)
  end
end
