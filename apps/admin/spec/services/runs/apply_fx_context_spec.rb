require 'rails_helper'

RSpec.describe Runs::ApplyFxContext do
  let(:input_json) do
    {
      'schemaVersion' => '1.0',
      'accounts' => [],
      'markets' => [],
      'trades' => [],
      'feeModel' => { 'enabled' => true },
      'priceSnapshot' => {
        'valuationTimestamp' => '2026-03-30T03:00:00Z',
        'prices' => []
      }
    }
  end

  before do
    ReportingSetting.current.update!(reporting_currency: 'ARS')
  end

  it 'persists resolved FX context into run input and fx_context' do
    FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: '1020.15',
      source: 'manual'
    )

    run = Run.create!(input_json: input_json)

    described_class.call(run: run)
    run.reload

    expect(run.fx_context).to include(
      'reportingCurrency' => 'ARS',
      'operatorFeeFactor' => '1.0',
      'rate' => '1020.15',
      'rateSource' => 'manual',
      'rateMissing' => false
    )
    expect(run.input_json).to include('fxContext')
  end

  it 'flags missing rates without raising' do
    run = Run.create!(input_json: input_json)

    described_class.call(run: run)
    run.reload

    expect(run.fx_context['rateMissing']).to be(true)
    expect(run.fx_context['rate']).to be_nil
  end
end
