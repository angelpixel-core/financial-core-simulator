require 'rails_helper'

RSpec.describe 'Event bus port contract' do
  it 'is satisfied by admin bus adapter and preserves projection compatibility' do
    adapter = Admin::Events::BusAdapter.new

    expect(adapter).to be_a(FCS::Ports::EventBus)

    envelope = adapter.publish('runs.execution.completed', { runId: 12, status: 'succeeded' })

    expect(envelope).to include(
      schemaVersion: '1.0',
      eventName: 'runs.execution.completed',
      eventType: 'RUN_LIFECYCLE_NORMALIZED'
    )
    expect(envelope[:projections]).to include('overview', 'trend')
  end
end
