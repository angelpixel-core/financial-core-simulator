require 'rails_helper'
require 'rack/test'

RSpec.describe 'Admin cross-context smoke', type: :request do
  let(:tempfile) { Tempfile.new(['demo-cross-context', '.xlsx']) }

  before do
    Admin::AccessControl::Roles::Repository.new.ensure_defaults!
  end

  after do
    tempfile.close
    tempfile.unlink
  end

  it 'keeps demo, runs, fx, dashboard, and auth flows healthy' do
    get '/admin/system-health', headers: viewer_headers
    expect(response).to have_http_status(:ok)

    get '/admin/fx/history', headers: viewer_headers
    expect(response).to have_http_status(:ok)

    run = Run.create!(status: :queued, input_json: { 'schemaVersion' => '1.0', 'trades' => [] })
    allow(Runs::Api).to receive(:execute).with(run: run, fee_enabled: true, explain: true, verbose: false)

    post "/runs/#{run.id}/execute", headers: operator_headers, as: :json
    expect(response).to have_http_status(:ok)

    upload = Rack::Test::UploadedFile.new(
      tempfile.path,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      original_filename: 'demo.xlsx'
    )
    parser_result = Admin::Demo::Datasets::ExcelToInputParser::Result.new(
      valid?: true,
      input: { trades: [{ timestamp: Time.utc(2026, 3, 30, 12, 0, 0).to_i }] },
      errors: []
    )
    allow(Admin::Demo::Datasets::ExcelToInputParser).to receive(:call).and_return(parser_result)
    allow(Runs::Execute).to receive_message_chain(:new, :call)
    allow(Runs::VerifyInputHash).to receive_message_chain(:new, :call)

    post '/admin/demo-datasets', params: { file: upload }, headers: operator_headers
    expect(response).to have_http_status(:found)
    expect(AccessControlAuditLog.where(action: 'authorization.session').exists?).to be(true)
  end

  def viewer_headers
    { 'X-Admin-User' => 'alice', 'X-Admin-Role' => 'viewer' }
  end

  def operator_headers
    { 'X-Admin-User' => 'ops', 'X-Admin-Role' => 'operator' }
  end
end
