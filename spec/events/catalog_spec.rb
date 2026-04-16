# frozen_string_literal: true

require_relative '../../lib/fcs'

RSpec.describe FCS::Events::Catalog do
  it 'returns canonical event metadata for known events' do
    metadata = described_class.new.fetch('runs.execution.completed')

    expect(metadata).to include(
      event_name: 'runs.execution.completed',
      event_type: 'RUN_LIFECYCLE_NORMALIZED',
      schema_version: '1.0',
      event_version: '1.0'
    )
  end

  it 'falls back to stable lifecycle metadata for unknown names' do
    metadata = described_class.new.fetch('unknown.event')

    expect(metadata).to include(
      event_name: 'unknown.event',
      event_type: 'RUN_LIFECYCLE_NORMALIZED',
      schema_version: '1.0',
      event_version: '1.0'
    )
  end
end
