require "rails_helper"

RSpec.describe Admin::DemoDataset::PreviewUpload do
  let(:parse_result_class) { Struct.new(:valid?, :input, :errors, keyword_init: true) }

  it "returns summary and sample rows" do
    file_adapter = instance_double(Admin::Demo::Datasets::FileAdapter)
    input = {
      schemaVersion: "1.0",
      accounts: [{accountId: "acc-1"}],
      markets: [{marketId: "ETH-USD"}],
      trades: [{tradeId: "trade-1"}],
      feeModel: {enabled: false}
    }
    allow(file_adapter).to receive(:parse).and_return(parse_result_class.new(valid?: true, input: input, errors: []))

    preview = described_class.new(file_adapter: file_adapter).call(file_path: "/tmp/demo.xlsx", timeline_enabled: true)

    expect(preview[:state]).to eq(:success)
    expect(preview[:summary]).to include(trades_count: 1, accounts_count: 1, markets_count: 1, schema_version: "1.0")
    expect(preview[:sample_rows]).to eq([{tradeId: "trade-1"}])
    expect(preview[:errors]).to eq([])
  end
end
