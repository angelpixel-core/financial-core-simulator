require 'rails_helper'

RSpec.describe Admin::Fx::ProcessRateUpload do
  ImportResult = Struct.new(:valid?, :errors, :message, keyword_init: true)

  it 'marks upload as success when importer result is valid' do
    upload = FxRateUpload.create!(
      status: 'processing',
      file_path: '/tmp/fake.xlsx',
      created_by_id: 1,
      created_by_role: 'operator',
      created_context: { 'locale' => 'en' },
      original_filename: 'fake.xlsx'
    )
    importer = class_double(Admin::Fx::RateUploadImporter)
    allow(importer).to receive(:call).and_return(ImportResult.new(valid?: true, errors: [], message: 'ok'))

    described_class.new(importer: importer).call(upload_id: upload.id)

    upload.reload
    expect(upload).to be_success_status
    expect(upload.error_count).to eq(0)
    expect(upload.error_message).to eq('ok')
  end

  it 'marks upload as error when importer returns validation errors' do
    upload = FxRateUpload.create!(
      status: 'processing',
      file_path: '/tmp/fake.xlsx',
      created_by_id: 1,
      created_by_role: 'operator',
      created_context: { 'locale' => 'en' },
      original_filename: 'fake.xlsx'
    )
    importer = class_double(Admin::Fx::RateUploadImporter)
    allow(importer).to receive(:call).and_return(
      ImportResult.new(valid?: false, errors: [{ message: 'invalid rate' }], message: nil)
    )

    described_class.new(importer: importer).call(upload_id: upload.id)

    upload.reload
    expect(upload).to be_error_status
    expect(upload.error_count).to eq(1)
    expect(upload.error_message).to eq('invalid rate')
  end
end
