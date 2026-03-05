module FCS
  module Ingestion
    class SourceEventValidator
      REQUIRED_FIELDS = %w[eventVersion source eventType correlationId occurredAt payload].freeze
      REQUIRED_STRING_FIELDS = %w[eventVersion source eventType correlationId occurredAt].freeze

      def validate!(event)
        validate_event_shape!(event)
        validate_required_fields!(event)
        validate_string_fields!(event)
        validate_payload!(event)

        true
      end

      def validate_batch!(events)
        validate_batch_shape!(events)

        accepted = []
        duplicates = []
        seen = {}

        events.each do |event|
          validate!(event)

          key = source_event_idempotency_key(event)
          fingerprint = source_event_fingerprint(event)
          previous = seen[key]

          if previous.nil?
            seen[key] = fingerprint
            accepted << event
            next
          end

          if previous == fingerprint
            duplicates << event
            next
          end

          raise_invalid!('source event idempotency key conflict for duplicate event',
                         field: 'sourceEvent.idempotencyKey')
        end

        { accepted: accepted, duplicates: duplicates }
      end

      private

      def validate_event_shape!(event)
        return if event.is_a?(Hash)

        raise_invalid!('source event must be an object', field: 'sourceEvent')
      end

      def validate_required_fields!(event)
        REQUIRED_FIELDS.each do |field|
          next if event.key?(field)

          raise_invalid!('missing required source event field', field: "sourceEvent.#{field}")
        end
      end

      def validate_string_fields!(event)
        REQUIRED_STRING_FIELDS.each do |field|
          validate_non_empty_string!(event.fetch(field), field: "sourceEvent.#{field}")
        end
      end

      def validate_payload!(event)
        return if event['payload'].is_a?(Hash)

        raise_invalid!('source event payload must be an object', field: 'sourceEvent.payload')
      end

      def validate_batch_shape!(events)
        return if events.is_a?(Array)

        raise_invalid!('source events batch must be an array', field: 'sourceEvents')
      end

      def source_event_idempotency_key(event)
        payload = event.fetch('payload')
        external_id = payload['externalId']
        sequence = payload['sequence']

        unless non_empty_string?(external_id) && !sequence.nil?
          raise_invalid!('source event idempotency identity requires payload.externalId and payload.sequence',
                         field: 'sourceEvent.idempotencyKey')
        end

        [event.fetch('source'), external_id.to_s, sequence.to_s]
      end

      def source_event_fingerprint(event)
        FCS::Hashing::CanonicalJSON.dump(event)
      end

      def validate_non_empty_string!(value, field:)
        return if value.is_a?(String) && !value.strip.empty?

        raise_invalid!('source event field must be a non-empty string', field: field)
      end

      def raise_invalid!(message, field:)
        raise FCS::Error.new(FCS::Errors::ERR_VALIDATION, message, details: { field: field })
      end

      def non_empty_string?(value)
        value.is_a?(String) && !value.strip.empty?
      end
    end
  end
end
