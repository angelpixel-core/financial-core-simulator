require 'rails_helper'
require 'bcrypt'

RSpec.describe Admin::AccessControl::AccountRoles::Repository do
  subject(:repository) { described_class.new }

  before do
    Admin::AccessControl::Roles::Repository.new.ensure_defaults!
  end

  it 'assigns persistent role to account and resolves it' do
    account = Account.create!(
      email: 'rbac-account@example.com',
      status: :verified,
      password_hash: BCrypt::Password.create('secret-pass')
    )

    repository.assign_role!(account_id: account.id, role_key: 'operator', assigned_by_id: 'admin-1')

    expect(repository.role_for_account(account)).to eq('operator')
    expect(repository.role_allowed?(actual_role: 'operator', required_role: 'viewer')).to be(true)
    expect(repository.role_allowed?(actual_role: 'operator', required_role: 'admin')).to be(false)
  end
end
