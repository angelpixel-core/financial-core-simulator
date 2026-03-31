require 'rails_helper'

RSpec.describe Admin::Fx::UploadRateGapProcessor do
  it 'creates placeholders and gaps for missing operational dates' do
    input = {
      'trades' => [
        { 'timestamp' => Time.utc(2026, 3, 29, 12, 0, 0).to_i },
        { 'timestamp' => Time.utc(2026, 3, 30, 12, 0, 0).to_i }
      ]
    }

    run = Run.create!(status: :succeeded, input_json: input)

    FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 29),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: '100',
      source: 'manual'
    )

    described_class.call(
      input: input,
      run: run,
      upload: nil,
      reporting_currency: 'ARS'
    )

    placeholder = FxDailyRate.find_by(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS'
    )

    expect(placeholder).to be_present
    expect(placeholder.source).to eq('placeholder')
    expect(placeholder.rate).to be_nil

    gap = FxRateGap.find_by(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS'
    )

    expect(gap).to be_present
    expect(gap.status).to eq('open')

    described_class.call(
      input: input,
      run: run,
      upload: nil,
      reporting_currency: 'ARS'
    )

    expect(FxRateGap.where(status: 'open').count).to eq(1)
  end
end
