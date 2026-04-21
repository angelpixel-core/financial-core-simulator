require 'rails_helper'
require 'capybara/rspec'
require 'bcrypt'
require_relative '../../support/system_helpers'

RSpec.describe 'Admin FX sync', type: :system, js: true do
  around do |example|
    previous_token = ENV['ADMIN_UI_TOKEN']
    ENV['ADMIN_UI_TOKEN'] = nil
    example.run
  ensure
    ENV['ADMIN_UI_TOKEN'] = previous_token
  end

  let(:email) { 'ops@example.com' }
  let(:password) { 'secret-pass' }

  before do
    driven_by(:selenium, using: :headless_chrome, screen_size: [1400, 900])
    Account.create!(
      email: email,
      status: :verified,
      password_hash: BCrypt::Password.create(password)
    )
    FxRateSource.create!(
      name: 'Banco Central de la Republica Argentina',
      code: 'BCRA',
      source_type: 'api',
      version: 'v1',
      config: { 'base_url' => 'https://api.bcra.gob.ar/estadisticascambiarias/v1.0' }
    )
  end

  it 'submits sync from history loader flow' do
    login_as_admin
    visit '/admin/fx/history'

    expect(page).to have_button(I18n.t('admin.fx.history.sync.source_label'), disabled: true)

    select 'Banco Central de la Republica Argentina', from: 'sync_source_id'
    expect(page).to have_select('sync_source_id', selected: 'Banco Central de la Republica Argentina')
    select 'USDARS', from: 'market'

    expect(page).to have_no_button(I18n.t('admin.fx.history.sync.source_label'), disabled: true)

    find("button[aria-label='#{I18n.t('admin.fx.history.sync.tooltip.run')}']").click

    expect(page).to have_current_path(%r{/admin/fx/history}, wait: 5)
    expect(page).to have_select('sync_source_id', selected: 'Banco Central de la Republica Argentina')
    expect(page).to have_select('market', selected: 'USDARS')
  end

  it 'transitions upload action from load label to play action after selecting a file' do
    login_as_admin
    visit '/admin/fx/history'

    expect(page).to have_button(I18n.t('admin.fx.history.loader.label'), disabled: true)

    file = Tempfile.new(['fx-upload', '.xlsx'])
    file.binmode
    file.write('dummy')
    file.rewind

    attach_file('fx-history-upload-file', file.path, make_visible: true)

    expect(page).to have_no_button(I18n.t('admin.fx.history.loader.label'), disabled: true)
    expect(page).to have_button(I18n.t('admin.fx.history.upload.tooltip.run'))
  ensure
    file&.close
    file&.unlink
  end

  def login_as_admin
    visit '/admin/login'
    fill_in 'admin-login-email', with: email
    fill_in 'admin-login-password', with: password
    click_button I18n.t('admin.auth.form.submit')
    wait_for_app_shell
  end
end
