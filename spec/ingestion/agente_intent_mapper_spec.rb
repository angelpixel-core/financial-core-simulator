require_relative '../../lib/fcs'
require 'json'

RSpec.describe FCS::Ingestion::AgenteIntentMapper do
  subject(:mapper) { described_class.new }

  def fixture(name)
    path = File.join(__dir__, '..', 'fixtures', 'source_events', name)
    JSON.parse(File.read(path))
  end

  it 'maps agente ORDER_INTENT_CREATED into canonical execution event' do
    source_event = fixture('valid_agente_intent.json')

    normalized = mapper.map!(source_event)

    expect(normalized).to include(
      'source' => 'agente.hft.alpha',
      'eventType' => 'AGENTE_INTENT_NORMALIZED',
      'correlationId' => 'corr-agent-001',
      'occurredAt' => '2026-03-04T10:00:00Z'
    )

    expect(normalized.fetch('payload')).to include(
      'agentId' => 'agente-1',
      'marketId' => 'ANG-ETH',
      'side' => 'BUY',
      'quantityBase' => '12.5',
      'priceQuotePerBase' => '0.0031'
    )

    expect(normalized.fetch('trace')).to include(
      'sourceEventType' => 'ORDER_INTENT_CREATED',
      'sourceEventVersion' => '1.0',
      'sourceCorrelationId' => 'corr-agent-001'
    )
  end

  it 'rejects non-agente event type for agente mapper' do
    source_event = fixture('valid_agente_intent.json')
    source_event['eventType'] = 'ORDER_FILLED'

    expect { mapper.map!(source_event) }
      .to raise_error(FCS::Error) { |error|
        expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(error.details).to include(field: 'sourceEvent.eventType')
      }
  end
end
