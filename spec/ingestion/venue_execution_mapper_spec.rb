require_relative '../../lib/fcs'
require 'json'

RSpec.describe FCS::Ingestion::VenueExecutionMapper do
  subject(:mapper) { described_class.new }

  def fixture(name)
    path = File.join(__dir__, '..', 'fixtures', 'source_events', name)
    JSON.parse(File.read(path))
  end

  it 'maps venue ORDER_FILLED into canonical execution event' do
    source_event = fixture('valid_venue_execution.json')

    normalized = mapper.map!(source_event)

    expect(normalized).to include(
      'source' => 'venue.internal.matcher',
      'eventType' => 'VENUE_EXECUTION_NORMALIZED',
      'correlationId' => 'corr-venue-001',
      'occurredAt' => '2026-03-04T10:00:01Z'
    )

    expect(normalized.fetch('payload')).to include(
      'externalOrderId' => 'ord-1001',
      'marketId' => 'ANG-ETH',
      'status' => 'FILLED',
      'filledQuantityBase' => '12.5',
      'avgFillPriceQuotePerBase' => '0.0030'
    )

    expect(normalized.fetch('trace')).to include(
      'sourceEventType' => 'ORDER_FILLED',
      'sourceEventVersion' => '1.0',
      'sourceCorrelationId' => 'corr-venue-001'
    )
  end

  it 'rejects non-venue execution event type for venue mapper' do
    source_event = fixture('valid_venue_execution.json')
    source_event['eventType'] = 'ORDER_INTENT_CREATED'

    expect { mapper.map!(source_event) }
      .to raise_error(FCS::Error) { |error|
        expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(error.details).to include(field: 'sourceEvent.eventType')
      }
  end
end
