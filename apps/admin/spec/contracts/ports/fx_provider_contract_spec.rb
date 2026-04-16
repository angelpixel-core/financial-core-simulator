require 'rails_helper'

RSpec.describe 'FX provider port contract' do
  let(:port_contract) { FCS::Ports::FxProvider }

  it 'is satisfied by manual adapter provider' do
    FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: '1200.25',
      source: 'manual'
    )

    provider = Admin::Fx::Providers::ManualAdapter.new
    result = provider.fetch_rate(base_currency: 'USD', quote_currency: 'ARS', at: Date.new(2026, 3, 30))

    expect(provider).to be_a(port_contract)
    expect(result).to include(
      rate: '1200.25',
      rate_source: 'manual',
      rate_missing: false,
      operational_date: Date.new(2026, 3, 30)
    )
  end

  it 'is satisfied by BCRA adapter provider' do
    client = instance_double(Admin::Fx::Providers::BcraClient)
    allow(client).to receive(:fetch_official_rate).and_return(
      { 'results' => [{ 'date' => '2026-03-30', 'close' => '1199.5' }] }
    )

    provider = Admin::Fx::Providers::BcraAdapter.new(client: client)
    result = provider.fetch_rate(base_currency: 'USD', quote_currency: 'ARS', at: Date.new(2026, 3, 30))

    expect(provider).to be_a(port_contract)
    expect(result).to include(
      rate: '1199.5',
      rate_source: 'bcra',
      rate_missing: false,
      operational_date: Date.new(2026, 3, 30)
    )
  end
end
