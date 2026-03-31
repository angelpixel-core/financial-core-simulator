require 'rails_helper'
require 'capybara/rspec'
require 'bcrypt'

RSpec.describe 'Admin FX reporting', type: :system do
  around do |example|
    travel_to(Time.zone.parse('2026-03-30 10:00:00')) { example.run }
  end

  before do
    driven_by(:selenium, using: :headless_chrome, screen_size: [1400, 900])
    Account.create!(
      email: 'ops@example.com',
      status: :verified,
      password_hash: BCrypt::Password.create('secret-pass')
    )
  end

  it 'shows the default reporting currency' do
    login
    visit '/admin/overview'
    ensure_sidebar_expanded

    expect(page).to have_select('reporting-currency', selected: 'USD')
  end

  it 'auto-saves the reporting currency on change' do
    login
    visit '/admin/overview'
    ensure_sidebar_expanded

    select 'ARS', from: 'reporting-currency'

    expect(page).to have_select('reporting-currency', selected: 'ARS')
    expect(ReportingSetting.current.reporting_currency).to eq('ARS')
  end

  it 'auto-saves the current daily rate from the sidebar' do
    ReportingSetting.current.update!(reporting_currency: 'ARS')
    FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: '1100.0',
      source: 'manual'
    )

    login
    visit '/admin/overview'
    ensure_sidebar_expanded

    fill_in I18n.t('admin.fx.reporting.rate_label', pair: 'USD/ARS'), with: '1200.5'
    find('body').click

    expect(page).to have_field('current-daily-rate', with: '1200.5', wait: 10)
    expect(FxDailyRate.where(operational_date: Date.new(2026, 3, 30)).exists?).to be(true)
    expect(FxDailyRate.order(:created_at).last.rate.to_s).to eq('1200.5')
  end

  it 'renders the missing rate popup and saves manual entry' do
    ReportingSetting.current.update!(reporting_currency: 'ARS')

    login
    visit '/admin/overview'
    ensure_sidebar_expanded

    expect(page).to have_css('.fx-missing-rate')
    fill_in I18n.t('admin.fx.popup.rate_label'), with: '1000.25'
    click_button I18n.t('admin.fx.popup.save_cta')

    expect(page).to have_no_css('.fx-missing-rate')
    expect(FxDailyRate.where(operational_date: Date.new(2026, 3, 30)).exists?).to be(true)
  end

  it 'allows carry forward when a prior rate exists' do
    ReportingSetting.current.update!(reporting_currency: 'ARS')
    FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 29),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: '900',
      source: 'manual'
    )

    login
    visit '/admin/overview'
    ensure_sidebar_expanded

    click_button I18n.t('admin.fx.popup.carry_forward_cta')

    expect(page).to have_no_css('.fx-missing-rate')
    expect(FxDailyRate.where(operational_date: Date.new(2026, 3, 30)).exists?).to be(true)
  end

  def login
    visit '/admin/login'
    fill_in 'admin-login-email', with: 'ops@example.com'
    fill_in 'admin-login-password', with: 'secret-pass'
    click_button I18n.t('admin.auth.form.submit')
  end

  def ensure_sidebar_expanded
    page.has_css?('.app-shell', wait: 10)
    return unless page.has_css?('.app-shell.app-shell--sidebar-collapsed', wait: 2)

    find('button[data-action="sidebar#expand"]').click
    expect(page).to have_no_css('.app-shell.app-shell--sidebar-collapsed', wait: 5)
  end
end
