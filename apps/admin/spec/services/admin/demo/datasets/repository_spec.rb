require 'rails_helper'

RSpec.describe Admin::Demo::Datasets::Repository do
  it 'creates valid trace with run and upload' do
    run, upload = described_class.new.create_valid_trace!(
      input_json: { 'schemaVersion' => '1.0', 'trades' => [] }
    )

    expect(run).to be_persisted
    expect(upload).to be_valid_status
    expect(upload.run_id).to eq(run.id)
  end

  it 'creates invalid trace without run' do
    upload = described_class.new.create_invalid_trace!(errors: [{ line: 2, code: 'INVALID_HEADERS' }])

    expect(upload).to be_invalid_status
    expect(upload.validation_errors).to include(include('code' => 'INVALID_HEADERS'))
  end
end
