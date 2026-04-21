require "rails_helper"

RSpec.describe Admin::Fx::Ingestion::Validators::BinanceContract do
  subject(:contract) { described_class.new }

  let(:valid_payload) do
    {
      status: 200,
      metadata: {
        resultset: {
          count: 1,
          offset: 0,
          limit: 1000
        },
        market: "BTCUSDT",
        interval: "1d"
      },
      results: [
        {
          open_time: 1_717_200_000_000,
          close: "68432.12",
          close_time: 1_717_286_399_999
        }
      ]
    }
  end

  it "accepts valid payloads" do
    result = contract.call(valid_payload)

    expect(result).to be_success
  end

  it "accepts empty results" do
    payload = valid_payload.merge(results: [], metadata: valid_payload[:metadata].merge(resultset: {count: 0, offset: 0, limit: 1000}))

    result = contract.call(payload)

    expect(result).to be_success
  end

  it "rejects invalid field types" do
    payload = valid_payload.merge(status: "200")

    result = contract.call(payload)

    expect(result).to be_failure
    expect(result.errors.to_h).to include(status: ["must be an integer"])
  end
end
