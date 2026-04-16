require 'rails_helper'

RSpec.describe 'Versioned event replay integration' do
  def deep_stringify(value)
    case value
    when Hash
      value.each_with_object({}) { |(key, item), out| out[key.to_s] = deep_stringify(item) }
    when Array
      value.map { |item| deep_stringify(item) }
    else
      value
    end
  end

  it 'replays schema-versioned envelopes end-to-end into projector read models' do
    router = Admin::Events::SchemaRouter.new

    completed = router.route(
      event_name: 'runs.execution.completed',
      payload: { runId: 'run-1', status: 'succeeded' },
      occurred_at: Time.utc(2026, 4, 16, 9, 0, 0),
      correlation_id: 'corr-run-1'
    )
    failed = router.route(
      event_name: 'runs.execution.failed',
      payload: { runId: 'run-2', status: 'failed' },
      occurred_at: Time.utc(2026, 4, 16, 10, 0, 0),
      correlation_id: 'corr-run-2'
    )

    stream = [completed, failed].map { |event| deep_stringify(event) }

    replay = FCS::Projector::ReadModelReplay.new(today: Date.new(2026, 4, 16))
    read_model = replay.apply_stream!(stream)

    expect(stream).to all(include('schemaVersion' => '1.0', 'eventVersion' => '1.0'))
    expect(read_model.fetch('overviewKpi')).to include('succeeded' => 1, 'failed' => 1)
    expect(read_model.fetch('latestRun')).to include(
      'runId' => 'run-2',
      'status' => 'failed',
      'correlationId' => 'corr-run-2'
    )
  end
end
