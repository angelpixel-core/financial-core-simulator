require "rails_helper"

RSpec.describe Admin::Observability::PrometheusMetricsAdapter do
  it "emits counter and histogram payloads through notifications" do
    adapter = described_class.new
    events = []

    subscriber = ActiveSupport::Notifications.subscribe("admin.observability.metric") do |_name, _start, _finish, _id, payload|
      events << payload
    end

    adapter.increment("runs.execution.completed", tags: {status: "succeeded"})
    adapter.observe("runs.execution.duration_ms", value: 42, tags: {status: "succeeded"})

    expect(events).to include(
      hash_including(type: "counter", metric: "runs.execution.completed", value: 1),
      hash_including(type: "histogram", metric: "runs.execution.duration_ms", value: 42)
    )
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
