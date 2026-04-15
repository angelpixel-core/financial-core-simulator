require 'rails_helper'

RSpec.describe Admin::Fx::StartRateUpload do
  it 'creates processing upload and stores file path' do
    file = instance_double('UploadedFile', original_filename: 'rates.xlsx', read: 'binary-content')

    upload = described_class.new.call(
      file: file,
      created_by_id: 1,
      created_by_role: 'operator',
      created_context: { 'source' => 'fx_history_upload' }
    )

    expect(upload).to be_processing_status
    expect(upload.file_path).to be_present
    expect(File.exist?(upload.file_path)).to be(true)
  ensure
    File.delete(upload.file_path) if upload&.file_path.present? && File.exist?(upload.file_path)
  end
end
