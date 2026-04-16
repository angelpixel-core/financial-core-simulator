require 'rails_helper'
require 'capybara/rspec'
require 'bcrypt'
require 'timeout'
require_relative '../../support/system_helpers'

RSpec.describe 'Admin FX reporting', type: :system do
  around do |example|
    previous_token = ENV['ADMIN_UI_TOKEN']
    ENV['ADMIN_UI_TOKEN'] = nil
    example.run
  ensure
    ENV['ADMIN_UI_TOKEN'] = previous_token
  end

  around do |example|
    travel_to(Time.zone.parse('2026-03-30 10:00:00')) { example.run }
  end

  before do
    driven_by(:selenium, using: :headless_chrome, screen_size: [1400, 900])
    Account.find_or_create_by!(email: 'ops@example.com') do |account|
      account.status = :verified
      account.password_hash = BCrypt::Password.create('secret-pass')
    end
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
      expect(page).to have_select('reporting-currency', selected: 'ARS', wait: 10)
      select 'ARS', from: 'reporting-currency'
      expect(page).to have_select('reporting-currency', selected: 'ARS')
    end
    wait_for_reporting_currency('ARS')
    expect(ReportingSetting.current.reload.reporting_currency).to eq('ARS')
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
    wait_for_fx_daily_rate(date: Date.new(2026, 3, 30), base: 'USD', quote: 'ARS')
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

    expect(page).to have_no_css('.fx-missing-rate', wait: 10)
    wait_for_fx_daily_rate(date: Date.new(2026, 3, 30), base: 'USD', quote: 'ARS')
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

    expect(page).to have_no_css('.fx-missing-rate', wait: 10)
    wait_for_fx_daily_rate(date: Date.new(2026, 3, 30), base: 'USD', quote: 'ARS')
  end

  def login
    visit '/admin/login'
    fill_in 'admin-login-email', with: 'ops@example.com'
    fill_in 'admin-login-password', with: 'secret-pass'
    click_button I18n.t('admin.auth.form.submit')
    wait_for_app_shell
  end

  def wait_for_reporting_currency(value)
    Timeout.timeout(5) do
      loop do
        ReportingSetting.current.reload
        break if ReportingSetting.current.reporting_currency == value

        sleep 0.1
      end
    end
  end

  def wait_for_fx_daily_rate(date:, base:, quote:)
    Timeout.timeout(5) do
      loop do
        rate = FxDailyRate.find_by(
          operational_date: date,
          base_currency: base,
          quote_currency: quote
        )
        break if rate.present?

        sleep 0.1
      end
    end
  end
end
