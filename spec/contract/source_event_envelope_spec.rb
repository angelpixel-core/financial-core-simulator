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
end
