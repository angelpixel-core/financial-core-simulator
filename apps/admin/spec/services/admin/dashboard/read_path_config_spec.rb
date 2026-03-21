require "rails_helper"

RSpec.describe Admin::Dashboard::ReadPathConfig do
  it "enables BFF read only for accepted true flag values" do
    %w[1 true on yes].each do |value|
      config = described_class.new(env: {"ADMIN_DASHBOARD_BFF_READ_ENABLED" => value})
      expect(config.bff_read_enabled?).to be(true)
    end
  end

  it "disables BFF read for unsupported values" do
    %w[0 false off no unexpected].each do |value|
      config = described_class.new(env: {"ADMIN_DASHBOARD_BFF_READ_ENABLED" => value})
      expect(config.bff_read_enabled?).to be(false)
    end
  end

  it "disables fallback when fallback flag is missing" do
    config = described_class.new(env: {})

    expect(config.fallback_enabled?).to be(false)
  end
end
