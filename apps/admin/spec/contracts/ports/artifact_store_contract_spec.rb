require 'rails_helper'
require 'tmpdir'

RSpec.describe 'Artifact store port contract' do
  it 'is satisfied by runs file-store adapter' do
    adapter = Admin::Runs::Artifacts::FileStoreAdapter.new

    expect(adapter).to be_a(FCS::Ports::ArtifactStore)

    output_dir = adapter.build_output_dir(run_id: 77)
    expect(File.directory?(output_dir)).to be(true)

    Dir.mktmpdir do |dir|
      json_path = File.join(dir, 'result.json')
      positions_path = File.join(dir, 'positions.csv')

      File.write(json_path, '{}')
      File.write(positions_path, 'account_id,market_id')

      result = {
        json_path: json_path,
        artifacts: {
          positions_csv_path: positions_path,
          pnl_csv_path: nil
        }
      }

      paths = adapter.artifact_paths(output_dir: output_dir, execution_result: result)

      expect(paths).to include(
        'result_json_path' => json_path,
        'positions_csv_path' => positions_path,
        'pnl_csv_path' => nil
      )
    end
  end
end
