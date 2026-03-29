require 'rails_helper'
require 'capybara/rspec'
require 'bcrypt'

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

    expect(page).to have_css('[data-controller="financial-overview"][data-financial-overview-state="empty"]')
    within('[data-controller="financial-overview"]') do
      expect(page).to have_css('[data-financial-overview-target="emptyState"]:not([hidden])')
      expect(page).to have_css('[data-financial-overview-target="cards"][hidden]', visible: :hidden)
      expect(page).to have_content(I18n.t('admin.overview.financial_overview.empty_title'))
    end
  end

  it 'renders chart containers when series are present' do
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
      }
    )

    login_as_admin
    visit '/admin/overview'

    expect(page).to have_css('[data-controller="financial-overview"][data-financial-overview-state="ready"]')
    within('[data-controller="financial-overview"]') do
      expect(page).to have_css('[data-financial-overview-target="activityChart"].is-ready')
      expect(page).to have_css('[data-financial-overview-target="volumeChart"].is-ready')
      expect(page).to have_css('.trend-chart__shell')
      expect(page).to have_css('[data-financial-overview-target="emptyState"][hidden]', visible: :hidden)
    end
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

    expect(page).to have_css('[data-controller="financial-overview"][data-financial-overview-state="empty"]')
    within('[data-controller="financial-overview"]') do
      expect(page).to have_css('[data-financial-overview-target="emptyState"]:not([hidden])')
      expect(page).to have_css('[data-financial-overview-target="cards"][hidden]', visible: :hidden)
      expect(page).to have_content(I18n.t('admin.overview.financial_overview.empty_title'))
    end
  end

  def login_as_admin
    visit '/admin/login'
    fill_in 'admin-login-email', with: email
    fill_in 'admin-login-password', with: password
    click_button I18n.t('admin.auth.form.submit')
  end
end
