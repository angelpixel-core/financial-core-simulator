require "rails_helper"

RSpec.describe Runs::Adapters::ActiveRecordRunRepository do
  let(:repository) { described_class.new }

  it "loads and persists runs through the port seam" do
    run = Run.create!(input_json: {"schemaVersion" => "1.0", "trades" => []})

    loaded = repository.find_run(run_id: run.id)
    expect(loaded.id).to eq(run.id)

    repository.save_run!(
      run_id: run.id,
      attributes: {
        status: :running,
        error_code: nil,
        error_message: nil
      }
    )

    expect(run.reload).to be_running
  end
end
