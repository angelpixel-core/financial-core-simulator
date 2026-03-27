# frozen_string_literal: true

module FCS
  module Ingestion
    # Validates source event payloads and batches.
    #
    # @example
    #   validator = FCS::Ingestion::SourceEventValidator.new
    #   validator.validate!(event)
    class SourceEventValidator
      REQUIRED_FIELDS = %w[eventVersion source eventType correlationId occurredAt payload].freeze
      REQUIRED_STRING_FIELDS = %w[eventVersion source eventType correlationId occurredAt].freeze

      # @param event [Hash]
      # @return [true]
      # @raise [FCS::Error]
      def validate!(event)
        validate_event_shape!(event)
        validate_required_fields!(event)
        validate_string_fields!(event)
        validate_payload!(event)

        true
      end

      # @param events [Array<Hash>]
      # @return [Hash] { accepted:, duplicates: }
      # @raise [FCS::Error]
      def validate_batch!(events)
        validate_batch_shape!(events)

        accepted = []
        duplicates = []
        guard = FCS::Ingestion::SourceEventIdempotencyGuard.new

        events.each do |event|
          validate!(event)

          classification = guard.classify!(event)
          if classification == :accepted
            accepted << event
            next
          end

          if classification == :duplicate
            duplicates << event
            next
          end

          raise_invalid!(t("fcs.ingestion.source_event_validator.idempotency_conflict_duplicate"),
            field: "sourceEvent.idempotencyKey")
        end

        {accepted: accepted, duplicates: duplicates}
      end

      private

      def validate_event_shape!(event)
        return if event.is_a?(Hash)

        raise_invalid!(t("fcs.ingestion.source_event_validator.event_must_be_object"), field: "sourceEvent")
      end

      def validate_required_fields!(event)
        REQUIRED_FIELDS.each do |field|
          next if event.key?(field)

          raise_invalid!(t("fcs.ingestion.source_event_validator.missing_required_field"),
            field: "sourceEvent.#{field}")
        end
      end

      def validate_string_fields!(event)
        REQUIRED_STRING_FIELDS.each do |field|
          validate_non_empty_string!(event.fetch(field), field: "sourceEvent.#{field}")
        end
      end

      def validate_payload!(event)
        return if event["payload"].is_a?(Hash)

        raise_invalid!(t("fcs.ingestion.source_event_validator.payload_must_be_object"),
          field: "sourceEvent.payload")
      end

      def validate_batch_shape!(events)
        return if events.is_a?(Array)

        raise_invalid!(t("fcs.ingestion.source_event_validator.batch_must_be_array"), field: "sourceEvents")
      end

      def validate_non_empty_string!(value, field:)
        return if value.is_a?(String) && !value.strip.empty?

        raise_invalid!(t("fcs.ingestion.source_event_validator.field_must_be_non_empty_string"), field: field)
      end

      def raise_invalid!(message, field:)
        raise FCS::Error.new(FCS::Errors::ERR_VALIDATION, message, details: {field: field})
      end

      def t(key, **opts)
        ::I18n.t(key, **opts)
      end
    end
  end
end
