require "rails_helper"

RSpec.describe Admin::Fx::SyncDateRange do
  around do |example|
    previous_open = ENV["BCRA_BANK_OPEN_HOUR_ART"]
    previous_default_days = ENV["FX_SYNC_DEFAULT_RANGE_DAYS"]
    previous_max_days = ENV["FX_SYNC_MAX_RANGE_DAYS"]
    example.run
  ensure
    ENV["BCRA_BANK_OPEN_HOUR_ART"] = previous_open
    ENV["FX_SYNC_DEFAULT_RANGE_DAYS"] = previous_default_days
    ENV["FX_SYNC_MAX_RANGE_DAYS"] = previous_max_days
  end

  let(:bcra_source) do
    FxRateSource.create!(
      name: "BCRA",
      code: "BCRA",
      source_type: "api",
      version: "v1",
      config: {"base_url" => "https://api.bcra.gob.ar/estadisticascambiarias/v1.0"}
    )
  end

  it "uses yesterday as upper bound before BCRA open hour in Argentina" do
    ENV["BCRA_BANK_OPEN_HOUR_ART"] = "10"
    now = Time.utc(2026, 4, 22, 4, 50, 0) # 01:50 ART

    result = described_class.defaults(source: bcra_source, now: now)

    expect(result.date_to).to eq(Date.new(2026, 4, 21))
  end

  it "uses today as upper bound after BCRA open hour in Argentina" do
    ENV["BCRA_BANK_OPEN_HOUR_ART"] = "10"
    now = Time.utc(2026, 4, 22, 14, 0, 0) # 11:00 ART

    result = described_class.defaults(source: bcra_source, now: now)

    expect(result.date_to).to eq(Date.new(2026, 4, 22))
  end

  it "rejects ranges wider than max days" do
    ENV["FX_SYNC_MAX_RANGE_DAYS"] = "3"

    result = described_class.resolve(
      source: bcra_source,
      date_from_param: "2026-04-01",
      date_to_param: "2026-04-10"
    )

    expect(result).not_to be_valid
    expect(result.error_message_key).to eq("admin.fx.history.sync.range_too_wide")
  end
end
