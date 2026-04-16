require 'rails_helper'

RSpec.describe Admin::Fx::Rates::Repository do
  let(:repository) { described_class.new }

  it 'finds or initializes rates by pair and date' do
    rate = repository.find_or_initialize(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS'
    )

    expect(rate).to be_new_record

    repository.save!(rate.tap { |record| record.assign_attributes(rate: '1000', source: 'manual') })

    loaded = repository.find_by(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS'
    )

    expect(loaded).to be_present
    expect(loaded.rate).to eq(BigDecimal(1000))
  end

  it 'creates placeholders with metadata' do
    placeholder = repository.create_placeholder!(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS',
      source_run_id: 12,
      source_upload_id: 25,
      created_context: { source: 'spec' }
    )

    expect(placeholder.placeholder?).to be(true)
    expect(placeholder.source_run_id).to eq(12)
    expect(placeholder.source_upload_id).to eq(25)
    expect(placeholder.created_context).to include('source' => 'spec')
  end
end
