require 'rails_helper'
require 'capybara/rspec'
require 'bcrypt'
require 'json'
require 'tempfile'

RSpec.describe 'Admin financial overview', type: :system, js: true do
  let(:email) { 'ops@example.com' }
  let(:password) { 'secret-pass' }

  before do
    driven_by(:selenium, using: :headless_chrome, screen_size: [1400, 900])
    Account.create!(
      email: email,
      status: :verified,
      password_hash: BCrypt::Password.create(password)
    )
  end

  it 'shows empty state when both series are empty' do
    Run.create!(
      status: :succeeded,
      input_json: {
        'schemaVersion' => '1.0',
        'trades' => []
      }
    )

    login_as_admin
    visit '/admin/overview'

    expect(page).to have_css('[data-financial-overview-target="emptyState"]:not([hidden])', wait: 10)
    within('[data-controller="financial-overview"]') do
      expect(page).to have_css('[data-financial-overview-target="cards"][hidden]', visible: :hidden)
      expect(page).to have_content(I18n.t('admin.overview.financial_overview.empty_title'))
    end
  end

  it 'renders chart containers when series are present' do
    temp = Tempfile.new(['result', '.json'])
    temp.write(JSON.generate(
                 {
                   'timeline' => {
                     'schema_version' => '1.0',
                     'points' => [
                       {
                         'timestamp' => '2026-03-29T12:00:00Z',
                         'account_id' => 'acc-1',
                         'market_id' => 'BTC-USD',
                         'realized_pnl' => '1',
                         'unrealized_pnl' => '2',
                         'total_pnl' => '3'
                       }
                     ]
                   }
                 }
               ))
    temp.rewind

    Run.create!(
      status: :succeeded,
      input_json: {
        'schemaVersion' => '1.0',
        'trades' => [
          {
            'timestamp' => '2026-03-29T12:00:00Z',
            'quantity' => '1.0',
            'price' => '100.0',
            'symbol' => 'BTC-USD'
          },
          {
            'timestamp' => '2026-03-29T12:05:00Z',
            'quantity' => '2.0',
            'price' => '150.0',
            'symbol' => 'BTC-USD'
          }
        ]
      },
      artifacts: { 'result_json_path' => temp.path }
    )

    login_as_admin
    visit '/admin/overview'

    expect(page).to have_css('[data-financial-overview-target="activityChart"].is-ready', wait: 10)
    within('[data-controller="financial-overview"]') do
      expect(page).to have_css('[data-financial-overview-target="volumeChart"].is-ready')
      expect(page).to have_css('[data-financial-overview-target="pnlChart"].is-ready')
      expect(page).to have_css('.trend-chart__shell')
      expect(page).to have_css('[data-financial-overview-target="emptyState"][hidden]', visible: :hidden)
    end
  ensure
    temp.close
    temp.unlink
  end

  it 'shows pnl empty state when timeline is missing' do
    Run.create!(
      status: :succeeded,
      input_json: {
        'schemaVersion' => '1.0',
        'trades' => [
          {
            'timestamp' => '2026-03-29T12:00:00Z',
            'quantity' => '1.0',
            'price' => '100.0',
            'symbol' => 'BTC-USD'
          }
        ]
      }
    )

    login_as_admin
    visit '/admin/overview'

    expect(page).to have_css('[data-financial-overview-target="pnlFallback"]:not([hidden])', wait: 10)
  end

  it 'falls back to empty state when the endpoint fails' do
    Run.create!(
      status: :succeeded,
      input_json: {
        'schemaVersion' => '1.0',
        'trades' => [
          {
            'timestamp' => '2026-03-29T12:00:00Z',
            'quantity' => '1.0',
            'price' => '100.0',
            'symbol' => 'BTC-USD'
          }
        ]
      }
    )

    allow(Admin::Dashboard::FinancialOverviewMetrics).to receive(:new)
      .and_raise(StandardError, 'financial-overview-error')

    login_as_admin
    visit '/admin/overview'

    expect(page).to have_css('[data-controller="financial-overview"][data-financial-overview-state="empty"]', wait: 10)
    within('[data-controller="financial-overview"]') do
      expect(page).to have_css('[data-financial-overview-target="emptyState"]:not([hidden])')
      expect(page).to have_css('[data-financial-overview-target="cards"][hidden]', visible: :hidden)
      expect(page).to have_content(I18n.t('admin.overview.financial_overview.empty_title'))
    end
  end

  it 'syncs filters to the URL' do
    Run.create!(
      status: :succeeded,
      input_json: {
        'schemaVersion' => '1.0',
        'accounts' => [{ 'accountId' => 'acc-1' }],
        'markets' => [{ 'marketId' => 'BTC-USD' }],
        'trades' => []
      }
    )

    login_as_admin
    visit '/admin/overview'

    select 'acc-1', from: 'financial-account-filter'
    select 'BTC-USD', from: 'financial-market-filter'

    expect(page).to have_current_path(/account_id=acc-1/, url: true)
    expect(page).to have_current_path(/market_id=BTC-USD/, url: true)
  end

  it 'highlights missing FX points and shows the tooltip warning' do
    FxRateGap.create!(
      operational_date: Date.new(2026, 3, 29),
      base_currency: 'USD',
      quote_currency: 'ARS',
      status: 'open'
    )
    FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: BigDecimal(100),
      source: 'manual'
    )
    FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 31),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: BigDecimal(110),
      source: 'manual'
    )

    temp = Tempfile.new(['result', '.json'])
    temp.write(JSON.generate(
                 {
                   'timeline' => {
                     'schema_version' => '1.0',
                     'points' => [
                       {
                         'timestamp' => '2026-03-30T12:00:00Z',
                         'realized_pnl' => '2',
                         'unrealized_pnl' => '3',
                         'total_pnl' => '5'
                       },
                       {
                         'timestamp' => '2026-03-31T12:00:00Z',
                         'realized_pnl' => '3',
                         'unrealized_pnl' => '4',
                         'total_pnl' => '7'
                       }
                     ]
                   }
                 }
               ))
    temp.rewind

    Run.create!(
      status: :succeeded,
      input_json: {
        'schemaVersion' => '1.0',
        'trades' => [
          { 'timestamp' => '2026-03-29T12:00:00Z', 'quantity' => '1.0', 'price' => '100.0', 'symbol' => 'BTC-USD' },
          { 'timestamp' => '2026-03-30T12:00:00Z', 'quantity' => '1.0', 'price' => '100.0', 'symbol' => 'BTC-USD' }
        ],
        'fxContext' => { 'reportingCurrency' => 'ARS' }
      },
      artifacts: { 'result_json_path' => temp.path }
    )

    login_as_admin
    visit '/admin/overview'

    expect(page).to have_css('[data-financial-overview-target="volumeChart"].is-ready', wait: 10)
    expect(page).to have_css('.trend-chart__dot--missing', visible: :all)

    warning_text = I18n.t('admin.overview.financial_overview.missing_rate_tooltip')
    within('[data-financial-overview-target="volumeChart"]') do
      find('.trend-chart__dot--missing', match: :first, visible: :all).hover
      expect(page).to have_content(warning_text)
    end
    within('[data-financial-overview-target="pnlChart"]') do
      find('.recharts-line-curve', match: :first).hover
      expect(page).not_to have_content(warning_text)
    end
  ensure
    temp.close
    temp.unlink
  end

  def login_as_admin
    visit '/admin/login'
    fill_in 'admin-login-email', with: email
    fill_in 'admin-login-password', with: password
    click_button I18n.t('admin.auth.form.submit')
  end
end
