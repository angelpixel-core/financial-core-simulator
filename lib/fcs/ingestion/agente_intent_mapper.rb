# frozen_string_literal: true

module FCS
  module Ingestion
    # Normalizes agente intent source events.
    class AgenteIntentMapper
      SUPPORTED_EVENT_TYPE = "ORDER_INTENT_CREATED"
      NORMALIZED_EVENT_TYPE = "AGENTE_INTENT_NORMALIZED"

      def map!(source_event)
        validate_source_event_shape!(source_event)
        validate_supported_event_type!(source_event)

        {
          "source" => source_event.fetch("source"),
          "eventType" => NORMALIZED_EVENT_TYPE,
          "correlationId" => source_event.fetch("correlationId"),
          "occurredAt" => source_event.fetch("occurredAt"),
          "payload" => normalized_payload(source_event.fetch("payload")),
          "trace" => trace_metadata(source_event)
        }
      end

      private

      def validate_source_event_shape!(source_event)
        return if source_event.is_a?(Hash)

        raise_invalid!("source event must be an object", field: "sourceEvent")
      end

      def validate_supported_event_type!(source_event)
        event_type = source_event.fetch("eventType", nil)
        return if event_type == SUPPORTED_EVENT_TYPE

        raise_invalid!("unsupported agente source event type", field: "sourceEvent.eventType")
      end

      def normalized_payload(payload)
        {
          "agentId" => payload.fetch("agentId"),
          "marketId" => payload.fetch("marketId"),
          "side" => payload.fetch("side"),
          "quantityBase" => payload.fetch("quantityBase"),
          "priceQuotePerBase" => payload.fetch("priceQuotePerBase")
        }
      end

      def trace_metadata(source_event)
        {
          "sourceEventType" => source_event.fetch("eventType"),
          "sourceEventVersion" => source_event.fetch("eventVersion"),
          "sourceCorrelationId" => source_event.fetch("correlationId")
        }
      end

      def raise_invalid!(message, field:)
        raise FCS::Error.new(FCS::Errors::ERR_VALIDATION, message, details: { field: field })
      end
    end
  end
end
