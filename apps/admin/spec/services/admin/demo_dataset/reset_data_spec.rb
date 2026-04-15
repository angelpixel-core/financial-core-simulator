require 'rails_helper'

RSpec.describe Admin::DemoDataset::ResetData do
  it 'clears runs and uploads' do
    Run.create!(input_json: { 'schemaVersion' => '1.0', 'trades' => [] })
    DemoDatasetUpload.create!(status: :invalid, validation_errors: [{ code: 'x' }])

    described_class.new.call

    expect(Run.count).to eq(0)
    expect(DemoDatasetUpload.count).to eq(0)
  end
end
