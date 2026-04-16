require 'rails_helper'

RSpec.describe Admin::AccessControl::Permissions::Repository do
  subject(:repository) { described_class.new }

  before do
    Admin::AccessControl::Roles::Repository.new.ensure_defaults!
  end

  it 'grants and resolves role permissions' do
    repository.grant!(role_key: 'operator', resource: 'fx.daily_rates', action: 'update')

    expect(repository.allowed?(role_key: 'operator', resource: 'fx.daily_rates', action: 'update')).to be(true)
    expect(repository.allowed?(role_key: 'viewer', resource: 'fx.daily_rates', action: 'update')).to be(false)
  end
end
