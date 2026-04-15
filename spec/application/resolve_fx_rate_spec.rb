# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Application::ResolveFxRate do
  it "delegates to the configured fx provider port" do
    provider = instance_double(FCS::Ports::FxProvider)
    allow(provider).to receive(:fetch_rate).and_return(
      {rate: "1100.5", rate_source: "manual", rate_missing: false, operational_date: Date.new(2026, 3, 30)}
    )

    result = described_class.new(fx_provider: provider).call(
      base_currency: "USD",
      quote_currency: "ARS",
      operational_date: Date.new(2026, 3, 30)
    )

    expect(provider).to have_received(:fetch_rate).with(
      base_currency: "USD",
      quote_currency: "ARS",
      at: Date.new(2026, 3, 30)
    )
    expect(result[:rate]).to eq("1100.5")
  end
end
