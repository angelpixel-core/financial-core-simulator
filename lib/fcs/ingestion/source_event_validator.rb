module FCS
  module Ingestion
    class SourceEventValidator
      REQUIRED_FIELDS = %w[eventVersion source eventType correlationId occurredAt payload].freeze

      def validate!(event)
        raise_invalid!('source event must be an object', field: 'sourceEvent') unless event.is_a?(Hash)

        REQUIRED_FIELDS.each do |field|
          raise_invalid!('missing required source event field', field: "sourceEvent.#{field}") unless event.key?(field)
        end

        validate_non_empty_string!(event['eventVersion'], field: 'sourceEvent.eventVersion')
        validate_non_empty_string!(event['source'], field: 'sourceEvent.source')
        validate_non_empty_string!(event['eventType'], field: 'sourceEvent.eventType')
        validate_non_empty_string!(event['correlationId'], field: 'sourceEvent.correlationId')
        validate_non_empty_string!(event['occurredAt'], field: 'sourceEvent.occurredAt')
        unless event['payload'].is_a?(Hash)
          raise_invalid!('source event payload must be an object',
                         field: 'sourceEvent.payload')
        end

        true
      end

      private

      def validate_non_empty_string!(value, field:)
        return if value.is_a?(String) && !value.strip.empty?

        raise_invalid!('source event field must be a non-empty string', field: field)
      end

      def raise_invalid!(message, field:)
        raise FCS::Error.new(FCS::Errors::ERR_VALIDATION, message, details: { field: field })
      end
    end
  end
end
