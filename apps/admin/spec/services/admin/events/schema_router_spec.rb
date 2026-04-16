require 'rails_helper'

RSpec.describe Admin::Events::SchemaRouter do
  it 'routes known run events with stable schema and projection keys' do
    router = described_class.new

    event = router.route(
      event_name: 'runs.execution.completed',
      payload: { runId: 1, status: 'succeeded' },
      occurred_at: Time.utc(2026, 4, 15, 10, 30, 0)
    )

    expect(event).to include(
      schemaVersion: '1.0',
      eventName: 'runs.execution.completed',
      eventType: 'RUN_LIFECYCLE_NORMALIZED',
      occurredAt: '2026-04-15T10:30:00Z'
    )
    expect(event[:payload]).to include(runId: 1, status: 'succeeded')
    expect(event[:projections]).to include('overview', 'trend')
  end

  it 'keeps compatibility for replay by preserving eventType for failed runs' do
    router = described_class.new

    success = router.route(event_name: 'runs.execution.completed', payload: { runId: 1 })
    failure = router.route(event_name: 'runs.execution.failed', payload: { runId: 1 })

    expect(success[:schemaVersion]).to eq('1.0')
    expect(failure[:schemaVersion]).to eq('1.0')
    expect(success[:eventType]).to eq('RUN_LIFECYCLE_NORMALIZED')
    expect(failure[:eventType]).to eq('RUN_LIFECYCLE_NORMALIZED')
  end
end
