require_relative '../../lib/fcs'
require 'json'

RSpec.describe FCS::Ingestion::SourceEventValidator do
  subject(:validator) { described_class.new }

  def fixture(name)
    path = File.join(__dir__, '..', 'fixtures', 'source_events', name)
    JSON.parse(File.read(path))
  end

  %w[eventVersion source eventType correlationId occurredAt payload].each do |required_key|
    it "rejects envelope when #{required_key} is missing" do
      event = fixture('valid_agente_intent.json')
      event.delete(required_key)

      expect { validator.validate!(event) }
        .to raise_error(FCS::Error) { |e|
          expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
          expect(e.details).to include(field: "sourceEvent.#{required_key}")
        }
    end
  end

  {
    'valid_agente_intent.json' => 'agente intent envelope',
    'valid_venue_execution.json' => 'venue execution envelope',
    'valid_faucet_issuance.json' => 'faucet issuance envelope'
  }.each do |file, label|
    it "accepts #{label} when required metadata is present" do
      expect { validator.validate!(fixture(file)) }.not_to raise_error
    end
  end

  {
    'invalid_agente_missing_correlation_id.json' => 'sourceEvent.correlationId',
    'invalid_venue_missing_event_type.json' => 'sourceEvent.eventType',
    'invalid_faucet_missing_payload.json' => 'sourceEvent.payload'
  }.each do |file, field|
    it "rejects #{file} with field #{field}" do
      expect { validator.validate!(fixture(file)) }
        .to raise_error(FCS::Error) { |e|
          expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
          expect(e.details).to include(field: field)
        }
    end
  end

  describe 'idempotency and semantic identity guards (RD-V2-007 2.1 RED)' do
    def with_identity(event, external_id:, sequence:)
      mutated = JSON.parse(JSON.generate(event))
      mutated['payload']['externalId'] = external_id
      mutated['payload']['sequence'] = sequence
      mutated
    end

    it 'accepts stream reattempt with exact duplicate identity only once' do
      base = with_identity(fixture('valid_agente_intent.json'), external_id: 'agente-order-dup-1', sequence: 10)
      duplicate = JSON.parse(JSON.generate(base))

      result = validator.validate_batch!([base, duplicate])

      expect(result).to include(accepted: array_including(base))
      expect(result.fetch(:accepted).size).to eq(1)
      expect(result.fetch(:duplicates).size).to eq(1)
    end

    it 'rejects semantic identity collision for same source+externalId+sequence with divergent payload' do
      first = with_identity(fixture('valid_venue_execution.json'), external_id: 'venue-fill-001', sequence: 42)
      second = with_identity(fixture('valid_venue_execution.json'), external_id: 'venue-fill-001', sequence: 42)
      second['payload']['quantityBase'] = '999.0000'

      expect { validator.validate_batch!([first, second]) }
        .to raise_error(FCS::Error) { |error|
          expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
          expect(error.details).to include(field: 'sourceEvent.idempotencyKey')
        }
    end
  end
end
