require_relative '../../lib/fcs'

RSpec.describe FCS::Ingestion::SourceEventValidator do
  subject(:validator) { described_class.new }

  def base_event
    {
      'eventVersion' => '1.0',
      'source' => 'agente.hft.alpha',
      'eventType' => 'ORDER_INTENT_CREATED',
      'correlationId' => 'corr-001',
      'occurredAt' => '2026-03-04T10:00:00Z',
      'payload' => {
        'agentId' => 'agente-1',
        'marketId' => 'ANG-ETH',
        'side' => 'BUY'
      }
    }
  end

  %w[eventVersion source eventType correlationId occurredAt payload].each do |required_key|
    it "rejects envelope when #{required_key} is missing" do
      event = base_event
      event.delete(required_key)

      expect { validator.validate!(event) }
        .to raise_error(FCS::Error) { |e|
          expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
          expect(e.details).to include(field: "sourceEvent.#{required_key}")
        }
    end
  end
end
