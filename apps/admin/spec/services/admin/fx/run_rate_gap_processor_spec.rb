require 'rails_helper'

RSpec.describe Admin::Fx::RunRateGapProcessor do
  it 'creates placeholders and gaps for supported pairs' do
    ReportingSetting.current.update!(reporting_currency: 'USD')

    input = {
      'trades' => [
        { 'timestamp' => Time.utc(2026, 3, 30, 12, 0, 0).to_i, 'marketId' => 'BTC-USD' },
        { 'timestamp' => Time.utc(2026, 3, 30, 13, 0, 0).to_i, 'marketId' => 'ETH_USD' }
      ],
      'timeline' => {
        'events' => [
          { 'timestamp' => Time.utc(2026, 3, 31, 1, 0, 0).to_i }
        ]
      },
      'markets' => [
        { 'marketId' => 'DOGE-USD' }
      ]
    }

    run = Run.create!(status: :succeeded, input_json: input)

    FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'BTC',
      quote_currency: 'USD',
      rate: '25000',
      source: 'manual'
    )

    described_class.call(run: run)

    manual_rate = FxDailyRate.find_by(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'BTC',
      quote_currency: 'USD'
    )
    expect(manual_rate.rate).to eq(BigDecimal(25_000))
    expect(manual_rate.source).to eq('manual')

    placeholder = FxDailyRate.find_by(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS'
    )
    expect(placeholder).to be_present
    expect(placeholder.source).to eq('placeholder')
    expect(placeholder.rate).to be_nil

    gap = FxRateGap.open_for(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS'
    )
    expect(gap).to be_present
    expect(gap.placeholder_rate_id).to eq(placeholder.id)

    expect(
      FxDailyRate.find_by(
        operational_date: Date.new(2026, 3, 31),
        base_currency: 'ETH',
        quote_currency: 'USD'
      )
    ).to be_present

    expect(
      FxDailyRate.find_by(
        operational_date: Date.new(2026, 3, 30),
        base_currency: 'DOGE',
        quote_currency: 'USD'
      )
    ).to be_nil

    existing_count = FxDailyRate.count
    described_class.call(run: run)
    expect(FxDailyRate.count).to eq(existing_count)
  end

  it 'does not create placeholders when no trades or timeline dates exist' do
    run = Run.create!(status: :succeeded, input_json: { 'trades' => [] })

    described_class.call(run: run)

    expect(FxDailyRate.count).to eq(0)
  end
end
