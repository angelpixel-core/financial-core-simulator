require 'rails_helper'
require 'capybara/rspec'
require 'bcrypt'
require_relative '../../support/system_helpers'

RSpec.describe 'Admin cross-context smoke', type: :system do
  before do
    driven_by(:selenium, using: :headless_chrome, screen_size: [1400, 900])
    Admin::AccessControl::Roles::Repository.new.ensure_defaults!
    Account.create!(
      email: 'ops@example.com',
      status: :verified,
      password_hash: BCrypt::Password.create('secret-pass')
    )
  end

  it 'loads overview, fx history, and system health paths' do
    login

    visit '/admin/overview'
    expect(page).to have_current_path(%r{/admin/overview}, wait: 10, url: true)

    visit '/admin/fx/history'
    expect(page).to have_content(I18n.t('admin.fx.history.title'), wait: 10)

    visit '/admin/system-health'
    expect(page).to have_content(I18n.t('admin.nav.runs'), wait: 10)
  end

  def login
    visit '/admin/login'
    fill_in 'admin-login-email', with: 'ops@example.com'
    fill_in 'admin-login-password', with: 'secret-pass'
    click_button I18n.t('admin.auth.form.submit')
    expect(page).to have_current_path(%r{/admin/overview}, wait: 10, url: true)
  end
end
