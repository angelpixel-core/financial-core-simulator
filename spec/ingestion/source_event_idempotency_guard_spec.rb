require_relative '../../lib/fcs'
require 'json'

RSpec.describe FCS::Ingestion::SourceEventIdempotencyGuard do
  subject(:guard) { described_class.new }

  def fixture(name)
    path = File.join(__dir__, '..', 'fixtures', 'source_events', name)
    JSON.parse(File.read(path))
  end

  def with_identity(event, external_id:, sequence:)
    mutated = JSON.parse(JSON.generate(event))
    mutated['payload']['externalId'] = external_id
    mutated['payload']['sequence'] = sequence
    mutated
  end

  it 'classifies first event as accepted' do
    event = with_identity(fixture('valid_agente_intent.json'), external_id: 'agente-order-1', sequence: 10)

    expect(guard.classify!(event)).to eq(:accepted)
  end

  it 'classifies exact duplicate event as duplicate' do
    first = with_identity(fixture('valid_venue_execution.json'), external_id: 'venue-fill-1', sequence: 42)
    duplicate = JSON.parse(JSON.generate(first))

    expect(guard.classify!(first)).to eq(:accepted)
    expect(guard.classify!(duplicate)).to eq(:duplicate)
  end

  it 'classifies same identity with changed payload as collision' do
    first = with_identity(fixture('valid_venue_execution.json'), external_id: 'venue-fill-2', sequence: 43)
    changed = with_identity(fixture('valid_venue_execution.json'), external_id: 'venue-fill-2', sequence: 43)
    changed['payload']['filledQuantityBase'] = '777.0000'

    expect(guard.classify!(first)).to eq(:accepted)
    expect(guard.classify!(changed)).to eq(:collision)
  end

  it 'raises validation error when identity fields are missing' do
    event = fixture('valid_faucet_issuance.json')

    expect { guard.classify!(event) }
      .to raise_error(FCS::Error) { |error|
        expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(error.details).to include(field: 'sourceEvent.idempotencyKey')
      }
  end
end
