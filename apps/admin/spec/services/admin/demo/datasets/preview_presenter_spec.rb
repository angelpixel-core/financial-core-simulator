require "rails_helper"

RSpec.describe Admin::Demo::Datasets::PreviewPresenter do
  Result = Struct.new(:valid?, :input, :errors, keyword_init: true)

  it "renders success payload with summary and sample rows" do
    result = Result.new(
      valid?: true,
      input: {
        schemaVersion: "1.0",
        accounts: [{accountId: "acc-1"}],
        markets: [{marketId: "ETH-USD"}],
        trades: [{tradeId: "trade-1"}],
        feeModel: {enabled: false}
      },
      errors: []
    )

    payload = described_class.new.present(result)

    expect(payload).to include(state: :success, errors: [])
    expect(payload[:summary]).to include(
      trades_count: 1,
      accounts_count: 1,
      markets_count: 1,
      schema_version: "1.0",
      fee_enabled: false
    )
    expect(payload[:sample_rows]).to eq([{tradeId: "trade-1"}])
  end
end
