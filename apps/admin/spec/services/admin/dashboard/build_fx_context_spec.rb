require 'rails_helper'

RSpec.describe Admin::Dashboard::BuildFxContext do
  around do |example|
    travel_to(Time.zone.parse('2026-03-30 10:00:00')) { example.run }
  end

  it 'returns identity context when reporting currency equals base currency' do
    ReportingSetting.current.update!(reporting_currency: 'USD')

    context = described_class.new.call

    expect(context[:base_currency]).to eq('USD')
    expect(context[:quote_currency]).to eq('USD')
    expect(context[:carry_forward_available]).to be(false)
    expect(context[:rate_state].rate).to eq('1.0')
  end

  it 'returns resolver context and carry-forward availability' do
    ReportingSetting.current.update!(reporting_currency: 'ARS')
    FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 29),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: '1000',
      source: 'manual'
    )
    FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: '1100',
      source: 'manual'
    )

    context = described_class.new.call

    expect(context[:base_currency]).to eq('USD')
    expect(context[:quote_currency]).to eq('ARS')
    expect(context[:carry_forward_available]).to be(true)
    expect(context[:rate_state].rate).to eq('1100.0')
  end
end
