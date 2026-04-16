require 'rails_helper'

RSpec.describe Admin::Fx::Gaps::Repository do
  let(:repository) { described_class.new }

  it 'creates and loads open gaps by pair and date' do
    placeholder = FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: nil,
      source: 'placeholder'
    )

    gap = repository.create_open!(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS',
      placeholder_rate_id: placeholder.id,
      source_run_id: 99,
      source_upload_id: nil,
      created_context: { source: 'spec' }
    )

    loaded = repository.open_for(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'usd',
      quote_currency: 'ars'
    )

    expect(loaded).to eq(gap)
    expect(loaded.status).to eq('open')
    expect(loaded.created_context).to include('source' => 'spec')
  end
end
