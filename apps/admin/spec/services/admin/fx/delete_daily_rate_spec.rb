require 'rails_helper'

RSpec.describe Admin::Fx::DeleteDailyRate do
  it 'deletes manual rates not linked to system' do
    rate = FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: '1000',
      source: 'manual'
    )

    described_class.new.call(rate_id: rate.id)

    expect(FxDailyRate.find_by(id: rate.id)).to be_nil
  end

  it 'blocks deletion when linked to system' do
    run = Run.create!(input_json: { 'schemaVersion' => '1.0', 'trades' => [] })
    rate = FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: '1000',
      source: 'manual',
      source_run_id: run.id
    )

    expect { described_class.new.call(rate_id: rate.id) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(FxDailyRate.find_by(id: rate.id)).not_to be_nil
  end
end
