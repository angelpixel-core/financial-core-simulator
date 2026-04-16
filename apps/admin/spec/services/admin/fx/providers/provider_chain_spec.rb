require 'rails_helper'

RSpec.describe Admin::Fx::Providers::ProviderChain do
  let(:operational_date) { Date.new(2026, 3, 30) }

  it 'returns first successful provider response' do
    manual = instance_double(Admin::Fx::Providers::ManualAdapter)
    bcra = instance_double(Admin::Fx::Providers::BcraAdapter)

    allow(manual).to receive(:fetch_rate).and_return(
      rate: '1000.1',
      rate_source: 'manual',
      rate_missing: false,
      operational_date: operational_date
    )
    allow(bcra).to receive(:fetch_rate)

    result = described_class.new(providers: [manual, bcra]).fetch_rate(
      base_currency: 'USD',
      quote_currency: 'ARS',
      at: operational_date
    )

    expect(result[:rate]).to eq('1000.1')
    expect(result[:rate_source]).to eq('manual')
    expect(bcra).not_to have_received(:fetch_rate)
  end

  it 'falls back to next provider when prior provider is missing' do
    manual = instance_double(Admin::Fx::Providers::ManualAdapter)
    bcra = instance_double(Admin::Fx::Providers::BcraAdapter)

    allow(manual).to receive(:fetch_rate).and_return(
      rate: nil,
      rate_source: 'manual',
      rate_missing: true,
      operational_date: operational_date
    )
    allow(bcra).to receive(:fetch_rate).and_return(
      rate: '1199.9',
      rate_source: 'bcra',
      rate_missing: false,
      operational_date: operational_date
    )

    result = described_class.new(providers: [manual, bcra]).fetch_rate(
      base_currency: 'USD',
      quote_currency: 'ARS',
      at: operational_date
    )

    expect(result[:rate]).to eq('1199.9')
    expect(result[:rate_source]).to eq('bcra')
  end
end
