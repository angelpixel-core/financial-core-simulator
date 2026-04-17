require 'rails_helper'
require 'capybara/rspec'

RSpec.describe 'Admin demo dataset header actions', type: :system, js: true do
  let(:tempfile) { Tempfile.new(['demo', '.xlsx']) }
  let(:preview_input) do
    {
      schemaVersion: '1.0',
      accounts: [{ accountId: 'acc-1' }],
      markets: [{ marketId: 'ETH-USD' }],
      trades: [
        {
          tradeId: 'trade-1',
          accountId: 'acc-1',
          marketId: 'ETH-USD',
          timestamp: 1_700_000_001,
          side: 'BUY',
          quantityBase: '1',
          priceQuotePerBase: '100'
        }
      ],
      feeModel: { enabled: false }
    }
  end

  let(:preview_result) do
    Admin::Demo::Datasets::ExcelToInputParser::Result.new(
      valid?: true,
      input: preview_input,
      errors: []
    )
  end

  before do
    driven_by(:selenium, using: :headless_chrome, screen_size: [1400, 900])
    Account.create!(
      email: 'ops@example.com',
      status: :verified,
      password_hash: BCrypt::Password.create('secret-pass')
    )

    allow(Admin::Demo::Datasets::ExcelToInputParser).to receive(:call).and_return(preview_result)
  end

  after do
    tempfile.close
    tempfile.unlink
  end

  it 'opens preview via review icon and allows clearing file' do
    visit '/admin/login'
    fill_in 'admin-login-email', with: 'ops@example.com'
    fill_in 'admin-login-password', with: 'secret-pass'
    click_button I18n.t('admin.auth.form.submit')

    visit '/admin/overview'

    expect(page).to have_no_css("section[aria-label='#{I18n.t('admin.overview.dataset.aria')}']")

    process_button = page.find("button[data-overview--dataset-actions-target='submitButton']", visible: :all)
    expect(process_button.disabled?).to eq(true)

    attach_file 'overview-dataset-upload-file', tempfile.path, make_visible: true
    expect(page).to have_css("button[data-overview--dataset-actions-target='submitButton']:not([disabled])", wait: 5)

    find("button[data-action='click->overview--dataset-actions#handleReviewClick']").click
    expect(page).to have_css('.demo-dataset-modal', wait: 10)
    expect(page).to have_content('trade-1')

    click_button I18n.t('admin.overview.dataset.preview.clear_attachment')
    expect(page).to have_no_css('.demo-dataset-modal', wait: 10)
    expect(page).to have_css("button[data-overview--dataset-actions-target='submitButton'][disabled]", wait: 5)
  end
end
