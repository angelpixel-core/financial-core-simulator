require "rails_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Admin::Runs::Artifacts::FileStoreAdapter do
  let(:adapter) { described_class.new }

  it "creates run output directory under storage/runs" do
    output_dir = adapter.build_output_dir(run_id: 101)

    expect(File.directory?(output_dir)).to be(true)
    expect(output_dir).to include("storage/runs/run_101_")
  end

  it "returns only existing artifact paths to support partial persistence" do
    output_dir = Dir.mktmpdir("run-artifacts")
    result_path = File.join(output_dir, "result.json")
    positions_path = File.join(output_dir, "positions.csv")
    pnl_path = File.join(output_dir, "pnl.csv")

    File.write(result_path, "{}")
    File.write(positions_path, "id,qty\n")

    execution_result = FCS::Contracts::RunExecutionResult.from_hash!(
      json_path: result_path,
      input_hash: "a" * 64,
      run_id: "123e4567-e89b-5d3a-a456-426614174000",
      schema_version: "1.0",
      valuation_timestamp: "2026-04-15T12:00:00Z",
      artifacts: {
        positions_csv_path: positions_path,
        pnl_csv_path: pnl_path
      }
    )

    paths = adapter.artifact_paths(output_dir: output_dir, execution_result: execution_result)

    expect(paths).to eq(
      "result_json_path" => result_path,
      "positions_csv_path" => positions_path,
      "pnl_csv_path" => nil
    )
  ensure
    FileUtils.rm_rf(output_dir) if output_dir
  end
end
