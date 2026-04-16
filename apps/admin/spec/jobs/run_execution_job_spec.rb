require "rails_helper"

RSpec.describe RunExecutionJob, type: :job do
  it "delegates execution through Runs::Api with default flags" do
    run = Run.create!(status: :queued, input_json: {"schemaVersion" => "1.0"})

    expect(Runs::Api).to receive(:execute_by_id).with(run_id: run.id, fee_enabled: true, explain: true, verbose: false)

    described_class.perform_now(run.id)
  end
end
