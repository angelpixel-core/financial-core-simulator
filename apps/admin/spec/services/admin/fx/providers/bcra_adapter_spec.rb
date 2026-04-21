require "rails_helper"

RSpec.describe Admin::Fx::Providers::BcraAdapter do
  let(:operational_date) { Date.new(2026, 3, 30) }

  it "returns a normalized successful response from BCRA payload" do
    client = instance_double(Admin::Fx::Providers::BcraClient)
    allow(client).to receive(:fetch_official_rate).and_return(
      {"results" => [{"date" => "2026-03-30", "close" => "1200.25"}]}
    )

    result = described_class.new(client: client).fetch_rate(
      base_currency: "USD",
      quote_currency: "ARS",
      at: operational_date
    )

    expect(result).to include(
      rate: "1200.25",
      rate_source: "bcra",
      rate_missing: false,
      operational_date: operational_date
    )
  end

  it "maps EUR/ARS without inversion" do
    client = instance_double(Admin::Fx::Providers::BcraClient)
    allow(client).to receive(:fetch_official_rate).and_return(
      {"results" => [{"date" => "2026-03-30", "close" => "1000"}]}
    )

    result = described_class.new(client: client).fetch_rate(
      base_currency: "EUR",
      quote_currency: "ARS",
      at: operational_date
    )

    expect(result).to include(
      rate: "1000.0",
      rate_source: "bcra",
      rate_missing: false,
      operational_date: operational_date
    )
  end

  it "returns a missing response when BCRA client is rate limited" do
    client = instance_double(Admin::Fx::Providers::BcraClient)
    allow(client).to receive(:fetch_official_rate).and_raise(Admin::Fx::Providers::BcraClient::RateLimitedError)

    result = described_class.new(client: client).fetch_rate(
      base_currency: "USD",
      quote_currency: "ARS",
      at: operational_date
    )

    expect(result).to include(
      rate: nil,
      rate_source: "bcra_rate_limited",
      rate_missing: true,
      operational_date: operational_date
    )
  end

  it "returns a missing response when BCRA payload is invalid" do
    client = instance_double(Admin::Fx::Providers::BcraClient)
    allow(client).to receive(:fetch_official_rate).and_return({"results" => [{"date" => "2026-03-30",
                                                                              "close" => "N/A"}]})

    result = described_class.new(client: client).fetch_rate(
      base_currency: "USD",
      quote_currency: "ARS",
      at: operational_date
    )

    expect(result).to include(
      rate: nil,
      rate_source: "bcra_invalid_payload",
      rate_missing: true,
      operational_date: operational_date
    )
  end

  it "returns a missing response when provider fails unexpectedly" do
    client = instance_double(Admin::Fx::Providers::BcraClient)
    allow(client).to receive(:fetch_official_rate).and_raise(StandardError, "timeout")

    result = described_class.new(client: client).fetch_rate(
      base_currency: "USD",
      quote_currency: "ARS",
      at: operational_date
    )

    expect(result).to include(
      rate: nil,
      rate_source: "bcra_unavailable",
      rate_missing: true,
      operational_date: operational_date
    )
  end
end
