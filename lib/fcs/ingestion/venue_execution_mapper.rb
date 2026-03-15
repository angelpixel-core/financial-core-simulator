module FCS
  module Ingestion
    class VenueExecutionMapper
      SUPPORTED_EVENT_TYPES = %w[
        ORDER_ACKNOWLEDGED
        ORDER_FILLED
        ORDER_CANCELLED
        ORDER_REJECTED
      ].freeze

      NORMALIZED_EVENT_TYPE = "VENUE_EXECUTION_NORMALIZED".freeze

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
        return if SUPPORTED_EVENT_TYPES.include?(event_type)

        raise_invalid!("unsupported venue source event type", field: "sourceEvent.eventType")
      end

      def normalized_payload(payload)
        normalized = {
          "externalOrderId" => payload.fetch("externalOrderId"),
          "marketId" => payload.fetch("marketId"),
          "status" => payload.fetch("status")
        }

        normalized["filledQuantityBase"] = payload.fetch("filledQuantityBase") if payload.key?("filledQuantityBase")

        if payload.key?("avgFillPriceQuotePerBase")
          normalized["avgFillPriceQuotePerBase"] = payload.fetch("avgFillPriceQuotePerBase")
        end

        normalized
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
