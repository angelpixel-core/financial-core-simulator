require 'rails_helper'

RSpec.describe Admin::Fx::RateUpserter do
  around do |example|
    travel_to(Time.zone.parse('2026-03-30 10:00:00')) { example.run }
  end

  it 'creates a placeholder when operational date enforcement is disabled' do
    rate = described_class.call(
      operational_date: Date.new(2026, 3, 29),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: nil,
      source: 'placeholder',
      source_run_id: 12,
      enforce_operational_date: false
    )

    expect(rate).to be_persisted
    expect(rate.source).to eq('placeholder')
    expect(rate.rate).to be_nil
    expect(rate.source_run_id).to eq(12)
  end

  it 'does not overwrite concrete rates with placeholders' do
    FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 29),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: '1000',
      source: 'manual'
    )

    described_class.call(
      operational_date: Date.new(2026, 3, 29),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: nil,
      source: 'placeholder',
      enforce_operational_date: false
    )

    rate = FxDailyRate.find_by(
      operational_date: Date.new(2026, 3, 29),
      base_currency: 'USD',
      quote_currency: 'ARS'
    )

    expect(rate.source).to eq('manual')
    expect(rate.rate).to eq(BigDecimal(1000))
  end

  it 'updates placeholder when manual rate is provided' do
    placeholder = described_class.call(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: nil,
      source: 'placeholder',
      enforce_operational_date: false
    )

    rate = described_class.call(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: '1020.5',
      source: 'manual'
    )

    expect(rate.id).to eq(placeholder.id)
    expect(rate.source).to eq('manual')
    expect(rate.rate).to eq(BigDecimal('1020.5'))
  end
end
