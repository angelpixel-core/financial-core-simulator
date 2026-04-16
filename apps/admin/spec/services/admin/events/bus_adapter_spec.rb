require 'rails_helper'

RSpec.describe Admin::Events::BusAdapter do
  it 'publishes envelope through notifications with versioned schema' do
    adapter = described_class.new
    captured = nil

    subscriber = ActiveSupport::Notifications.subscribe('admin.events.publish') do |_name, _start, _finish, _id, payload|
      captured = payload
    end

    envelope = adapter.publish('runs.execution.completed', { runId: 9 })

    expect(envelope[:schemaVersion]).to eq('1.0')
    expect(envelope[:eventName]).to eq('runs.execution.completed')
    expect(envelope[:eventType]).to eq('RUN_LIFECYCLE_NORMALIZED')
    expect(captured).to eq(envelope)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
