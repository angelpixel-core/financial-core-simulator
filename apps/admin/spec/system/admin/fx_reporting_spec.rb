require 'rails_helper'
require 'capybara/rspec'
require 'bcrypt'
require_relative '../../support/system_helpers'

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
    wait_for_sidebar_panel('admin.fx.reporting.aria')

    within_sidebar_panel('admin.fx.reporting.aria') do
      expect(page).to have_select('reporting-currency', selected: 'USD')
    end
  end

  it 'auto-saves the reporting currency on change' do
    login
    visit '/admin/overview'
    wait_for_sidebar_panel('admin.fx.reporting.aria')

    within_sidebar_panel('admin.fx.reporting.aria') do
      expect(page).to have_css('form[data-controller="auto-submit"] select#reporting-currency', wait: 10)
      select 'ARS', from: 'reporting-currency'
      expect(page).to have_select('reporting-currency', selected: 'ARS')
    end
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
    wait_for_sidebar_panel('admin.fx.reporting.aria')

    within_sidebar_panel('admin.fx.reporting.aria') do
      expect(page).to have_css('form[data-controller="auto-submit"] input#current-daily-rate', wait: 10)
      fill_in I18n.t('admin.fx.reporting.rate_label', pair: 'USD/ARS'), with: '1200.5'
    end

    page.find('body').click

    expect(page).to have_field('current-daily-rate', with: '1200.5', wait: 10)
    expect(FxDailyRate.where(operational_date: Date.new(2026, 3, 30)).exists?).to be(true)
    expect(FxDailyRate.order(:created_at).last.rate.to_s).to eq('1200.5')
  end

  it 'renders the missing rate popup and saves manual entry' do
    ReportingSetting.current.update!(reporting_currency: 'ARS')

    login
    visit '/admin/overview'
    wait_for_sidebar_panel('admin.fx.reporting.aria')

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
    wait_for_sidebar_panel('admin.fx.reporting.aria')

    click_button I18n.t('admin.fx.popup.carry_forward_cta')

    expect(page).to have_no_css('.fx-missing-rate')
    expect(FxDailyRate.where(operational_date: Date.new(2026, 3, 30)).exists?).to be(true)
  end

  def login
    visit '/admin/login'
    fill_in 'admin-login-email', with: 'ops@example.com'
    fill_in 'admin-login-password', with: 'secret-pass'
    click_button I18n.t('admin.auth.form.submit')
    expect(page).to have_current_path(%r{/admin/overview}, wait: 10, url: true)
  end
end
