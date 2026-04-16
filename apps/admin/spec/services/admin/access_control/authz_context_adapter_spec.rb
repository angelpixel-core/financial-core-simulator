require 'rails_helper'
require 'bcrypt'

RSpec.describe Admin::AccessControl::AuthzContextAdapter do
  it 'builds auth context from request and actor data' do
    account = Account.create!(
      email: 'ctx-user@example.com',
      status: :verified,
      password_hash: BCrypt::Password.create('secret-pass')
    )

    request = ActionDispatch::TestRequest.create
    request.path = '/admin/overview'
    request.request_method = 'GET'

    context = described_class.new(request: request).call(
      account: account,
      role: 'operator',
      required_role: 'viewer',
      gate: 'session'
    )

    expect(context[:account_id]).to eq(account.id.to_s)
    expect(context[:role]).to eq('operator')
    expect(context[:required_role]).to eq('viewer')
    expect(context[:gate]).to eq('session')
  end
end
