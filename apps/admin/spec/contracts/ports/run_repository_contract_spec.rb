require "rails_helper"

RSpec.describe "Run repository port contract" do
  let(:port_contract) { FCS::Ports::RunRepository }

  it "is satisfied by active-record run repository" do
    repository = Runs::Repositories::ActiveRecord::RunRepository.new
    run = Run.create!(status: :queued, input_json: {"schemaVersion" => "1.0", "trades" => []})

    expect(repository).to be_a(port_contract)
    expect(repository.find_run(run_id: run.id).id).to eq(run.id)

    repository.save_run!(run_id: run.id, attributes: {status: :running})
    expect(run.reload).to be_running
  end

  it "is also satisfied by the legacy adapter wrapper" do
    repository = Runs::Adapters::ActiveRecordRunRepository.new
    run = Run.create!(status: :queued, input_json: {"schemaVersion" => "1.0", "trades" => []})

    expect(repository).to be_a(port_contract)
    repository.save_run!(run_id: run.id, attributes: {status: :failed, error_message: "x"})

    persisted = repository.find_run(run_id: run.id)
    expect(persisted).to be_failed
    expect(persisted.error_message).to eq("x")
  end
end
