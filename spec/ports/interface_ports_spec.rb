# frozen_string_literal: true

require_relative '../../lib/fcs'

RSpec.describe 'FCS ports interfaces' do
  it 'defines run repository abstract methods' do
    port = FCS::Ports::RunRepository.new

    expect { port.save_run!({}) }.to raise_error(NotImplementedError)
    expect { port.find_run('run-1') }.to raise_error(NotImplementedError)
  end

  it 'defines fx provider abstract method' do
    port = FCS::Ports::FxProvider.new

    expect { port.fetch_rate(base_currency: 'EUR', quote_currency: 'USD') }.to raise_error(NotImplementedError)
  end

  it 'defines event bus abstract method' do
    port = FCS::Ports::EventBus.new

    expect { port.publish('run.completed', { runId: 'run-1' }) }.to raise_error(NotImplementedError)
  end
end
