require 'rails_helper'

RSpec.describe Admin::Fx::RateResolver do
  let(:operational_date) { Date.new(2026, 3, 30) }

  it 'returns identity rate when base and quote match' do
    result = described_class.call(
      base_currency: 'USD',
      quote_currency: 'USD',
      operational_date: operational_date
    )

    expect(result.rate).to eq('1.0')
    expect(result.rate_missing).to be(false)
    expect(result.rate_source).to eq('identity')
  end

  it 'returns missing when no rate exists' do
    result = described_class.call(
      base_currency: 'USD',
      quote_currency: 'ARS',
      operational_date: operational_date
    )

    expect(result.rate).to be_nil
    expect(result.rate_missing).to be(true)
    expect(result.rate_source).to be_nil
  end

  it 'returns stored rate metadata when present' do
    FxDailyRate.create!(
      operational_date: operational_date,
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: BigDecimal('1020.15'),
      source: 'manual'
    )

    result = described_class.call(
      base_currency: 'USD',
      quote_currency: 'ARS',
      operational_date: operational_date
    )

    expect(result.rate).to eq('1020.15')
    expect(result.rate_missing).to be(false)
    expect(result.rate_source).to eq('manual')
  end
end
