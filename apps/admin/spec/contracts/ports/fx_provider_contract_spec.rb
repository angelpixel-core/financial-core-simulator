require 'rails_helper'

RSpec.describe 'FX provider port contract' do
  let(:port_contract) { FCS::Ports::FxProvider }

  it 'is satisfied by rate resolver provider' do
    FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: '1200.25',
      source: 'manual'
    )

    provider = Admin::Fx::Adapters::RateResolverProvider.new
    result = provider.fetch_rate(base_currency: 'USD', quote_currency: 'ARS', at: Date.new(2026, 3, 30))

    expect(provider).to be_a(port_contract)
    expect(result).to include(
      rate: '1200.25',
      rate_source: 'manual',
      rate_missing: false,
      operational_date: Date.new(2026, 3, 30)
    )
  end
end
