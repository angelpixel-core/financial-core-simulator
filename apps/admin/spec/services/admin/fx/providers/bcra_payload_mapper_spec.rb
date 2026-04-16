require "rails_helper"

RSpec.describe Admin::Fx::Providers::BcraPayloadMapper do
  it "maps a valid BCRA payload into normalized rate fields" do
    payload = {
      "results" => [
        {"date" => "2026-03-30", "close" => "1188.42"}
      ]
    }

    result = described_class.new.call(payload)

    expect(result).to eq(
      rate: "1188.42",
      rate_date: "2026-03-30"
    )
  end

  it "raises invalid payload when results are missing" do
    expect do
      described_class.new.call({"status" => "ok"})
    end.to raise_error(Admin::Fx::Providers::BcraPayloadMapper::InvalidPayloadError)
  end

  it "raises invalid payload when close rate is not numeric" do
    expect do
      described_class.new.call("results" => [{"date" => "2026-03-30", "close" => "N/A"}])
    end.to raise_error(Admin::Fx::Providers::BcraPayloadMapper::InvalidPayloadError)
  end
end
