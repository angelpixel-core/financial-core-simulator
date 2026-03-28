require "rails_helper"
require "view_component/test_helpers"

RSpec.describe Admin::DemoDataset::PreviewModalComponent, type: :component do
  include ViewComponent::TestHelpers

  it "limits sample rows and renders summary" do
    rows = (1..15).map do |index|
      {
        tradeId: "trade-#{index}",
        accountId: "account-#{index}",
        marketId: "ETH-USD",
        timestamp: 1_700_000_000 + index,
        side: "BUY",
        quantityBase: "1",
        priceQuotePerBase: "100"
      }
    end

    summary = {
      trades_count: 15,
      accounts_count: 10,
      markets_count: 1,
      schema_version: "1.0",
      fee_enabled: false
    }

    render_inline(described_class.new(
      state: :success,
      summary: summary,
      sample_rows: rows,
      errors: [],
      file_name: "demo.xlsx"
    ))

    expect(rendered_content).to include(I18n.t("admin.overview.dataset.preview.summary_title"))
    expect(rendered_content).to include("trade-12")
    expect(rendered_content).not_to include("trade-13")
  end
end
