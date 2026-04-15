# frozen_string_literal: true

require_relative '../../lib/fcs'

RSpec.describe FCS::Contracts::FxRateInput do
  it 'normalizes fx rate fields' do
    rate = described_class.from_hash!(
      baseCurrency: :EUR,
      quoteCurrency: 'USD',
      rate: 1.08,
      asOf: '2026-04-15T10:00:00Z'
    )

    expect(rate).to eq(
      baseCurrency: 'EUR',
      quoteCurrency: 'USD',
      rate: '1.08',
      asOf: '2026-04-15T10:00:00Z'
    )
  end

  it 'raises when a required field is blank' do
    expect do
      described_class.from_hash!(
        baseCurrency: '',
        quoteCurrency: 'USD',
        rate: '1.08'
      )
    end.to raise_error(ArgumentError, /Missing required fields/)
  end
end
