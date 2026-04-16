require 'rails_helper'

RSpec.describe Admin::DemoDataset::ProcessUpload do
  let(:parse_result_class) { Struct.new(:valid?, :input, :errors, keyword_init: true) }

  it 'creates run and valid upload for valid parser output' do
    file_adapter = instance_double(Admin::Demo::Datasets::FileAdapter)
    input = {
      'schemaVersion' => '1.0',
      'feeModel' => { 'enabled' => true },
      'trades' => []
    }
    allow(file_adapter).to receive(:parse).and_return(parse_result_class.new(valid?: true, input: input, errors: []))

    executed = false
    verified = false
    processed_gaps = false

    outcome = described_class.new(
      file_adapter: file_adapter,
      execute_run: ->(_run, fee_enabled:) { executed = fee_enabled == true },
      verify_input_hash: ->(_run) { verified = true },
      process_upload_rate_gaps: ->(_input, _run, _upload, _currency) { processed_gaps = true }
    ).call(file_path: '/tmp/demo.xlsx', timeline_enabled: true)

    expect(outcome[:valid]).to be(true)
    expect(outcome[:run]).to be_present
    expect(outcome[:upload]).to be_present
    expect(outcome[:upload]).to be_valid_status
    expect(executed).to be(true)
    expect(verified).to be(true)
    expect(processed_gaps).to be(true)
  end

  it 'creates invalid upload when parser output is invalid' do
    file_adapter = instance_double(Admin::Demo::Datasets::FileAdapter)
    errors = [{ line: 2, code: 'INVALID_HEADERS' }]
    allow(file_adapter).to receive(:parse).and_return(parse_result_class.new(valid?: false, input: { 'trades' => [] },
                                                                             errors: errors))

    outcome = described_class.new(file_adapter: file_adapter).call(file_path: '/tmp/demo.xlsx', timeline_enabled: true)

    expect(outcome[:valid]).to be(false)
    expect(outcome[:run]).to be_nil
    expect(outcome[:upload]).to be_invalid_status
    expect(outcome[:errors]).to eq(errors)
  end
end
