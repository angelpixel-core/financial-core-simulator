require 'rails_helper'
require 'rack/test'

RSpec.describe 'Admin demo dataset preview', type: :request do
  let(:tempfile) { Tempfile.new(['demo', '.xlsx']) }
  let(:upload) do
    Rack::Test::UploadedFile.new(
      tempfile.path,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      original_filename: 'demo.xlsx'
    )
  end

  after do
    tempfile.close
    tempfile.unlink
  end

  it 'returns error state when file is missing' do
    post '/admin/demo-datasets/preview', headers: admin_session_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('turbo-frame id="demo-dataset-preview"')
    expect(response.body).to include(I18n.t('admin.overview.dataset.preview.error_title'))
  end

  it 'returns preview summary and sample rows for valid upload' do
    input = {
      schemaVersion: '1.0',
      accounts: [{ accountId: 'acc-1' }],
      markets: [{ marketId: 'ETH-USD' }],
      trades: [
        {
          tradeId: 'trade-1',
          accountId: 'acc-1',
          marketId: 'ETH-USD',
          timestamp: 1_700_000_001,
          side: 'BUY',
          quantityBase: '1',
          priceQuotePerBase: '100'
        }
      ],
      feeModel: { enabled: false }
    }

    result = Admin::DemoDataset::ExcelToInputParser::Result.new(
      valid?: true,
      input: input,
      errors: []
    )

    allow(Admin::DemoDataset::ExcelToInputParser).to receive(:call).and_return(result)

    post '/admin/demo-datasets/preview', params: { file: upload }, headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('turbo-frame id="demo-dataset-preview"')
    expect(response.body).to include(I18n.t('admin.overview.dataset.preview.summary_title'))
    expect(response.body).to include('trade-1')
  end

  it 'returns validation errors for invalid upload' do
    result = Admin::DemoDataset::ExcelToInputParser::Result.new(
      valid?: false,
      input: { trades: [] },
      errors: [{ line: 2, code: 'INVALID_HEADERS' }]
    )

    allow(Admin::DemoDataset::ExcelToInputParser).to receive(:call).and_return(result)

    post '/admin/demo-datasets/preview', params: { file: upload }, headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t('admin.overview.dataset.preview.invalid_title'))
    expect(response.body).to include('INVALID_HEADERS')
  end

  def admin_session_headers
    { 'X-Admin-User' => 'ops', 'X-Admin-Role' => 'operator' }
  end
end
