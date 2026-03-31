require 'rails_helper'

RSpec.describe FxRateGap, type: :model do
  it 'resolves with a linked rate' do
    placeholder = FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 29),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: nil,
      source: 'placeholder'
    )

    gap = described_class.create!(
      operational_date: placeholder.operational_date,
      base_currency: placeholder.base_currency,
      quote_currency: placeholder.quote_currency,
      status: 'open',
      placeholder_rate: placeholder
    )

    placeholder.update!(rate: '100.5', source: 'manual')

    gap.resolve!(rate: placeholder)

    expect(gap.status).to eq('resolved')
    expect(gap.resolved_rate_id).to eq(placeholder.id)
    expect(gap.resolved_at).to be_present
  end
end
