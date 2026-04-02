require "rails_helper"
require "capybara/rspec"

RSpec.describe "Admin demo dataset preview modal", type: :system, js: true do
  let(:tempfile) { Tempfile.new(["demo", ".xlsx"]) }
  let(:preview_input) do
    {
      schemaVersion: "1.0",
      accounts: [{accountId: "acc-1"}],
      markets: [{marketId: "ETH-USD"}],
      trades: [
        {
          tradeId: "trade-1",
          accountId: "acc-1",
          marketId: "ETH-USD",
          timestamp: 1_700_000_001,
          side: "BUY",
          quantityBase: "1",
          priceQuotePerBase: "100"
        }
      ],
      feeModel: {enabled: false}
    }
  end
  let(:preview_result) do
    Admin::DemoDataset::ExcelToInputParser::Result.new(
      valid?: true,
      input: preview_input,
      errors: []
    )
  end

  before do
    driven_by(:selenium, using: :headless_chrome, screen_size: [1400, 900])
    Account.create!(
      email: "ops@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )

    allow(Admin::DemoDataset::ExcelToInputParser).to receive(:call) do
      sleep 0.2
      preview_result
    end
  end

  after do
    tempfile.close
    tempfile.unlink
  end

  it "opens the preview modal, shows loading state, and clears on close" do
    visit "/admin/login"
    fill_in "admin-login-email", with: "ops@example.com"
    fill_in "admin-login-password", with: "secret-pass"
    click_button I18n.t("admin.auth.form.submit")

    visit "/admin/overview"

    attach_file "demo-dataset-upload-file", tempfile.path
    click_button I18n.t("admin.overview.dataset.preview.cta")

    expect(page).to have_css(".demo-dataset-preview.demo-dataset-preview--loading")
    expect(page).to have_css(".demo-dataset-preview.demo-dataset-preview--open")
    expect(page).to have_css(".demo-dataset-modal")
    expect(page).to have_content("trade-1")

    find(".demo-dataset-modal__close").click

    expect(page).to have_no_css(".demo-dataset-modal")
    expect(page.evaluate_script("document.querySelector('turbo-frame#demo-dataset-preview').innerHTML")).to eq("")
  end
end
