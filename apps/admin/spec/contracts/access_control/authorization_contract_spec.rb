require 'rails_helper'

RSpec.describe 'Authorization contract (allow/deny/audit)', type: :request do
  let(:request) { ActionDispatch::TestRequest.create }

  before do
    Admin::AccessControl::Roles::Repository.new.ensure_defaults!
  end

  it 'records audit event for allow decision' do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('ADMIN_UI_TOKEN').and_return('ui-secret')
    request.headers['X-Admin-Token'] = 'ui-secret'

    authorization = Admin::Authorization.new(request: request)

    expect(authorization.allow_machine_or_session?(required_role: 'viewer', token_key: 'ADMIN_UI_TOKEN')).to be(true)
    expect(AccessControlAuditLog.order(:id).last).to have_attributes(action: 'authorization.machine', outcome: 'allow')
  end

  it 'records audit event for deny decision' do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('ADMIN_UI_TOKEN').and_return('ui-secret')

    authorization = Admin::Authorization.new(request: request)

    expect(authorization.allow_machine_or_session?(required_role: 'viewer', token_key: 'ADMIN_UI_TOKEN')).to be(false)
    expect(AccessControlAuditLog.order(:id).last).to have_attributes(action: 'authorization.machine', outcome: 'deny')
  end
end
