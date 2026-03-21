# frozen_string_literal: true

module FCS
  module Ingestion
    # Dispatches source events to the right normalization mapper.
    #
    # @example
    #   pipeline = FCS::Ingestion::SourceEventNormalizationPipeline.new
    #   pipeline.normalize!(event)
    class SourceEventNormalizationPipeline
      SOURCE_MAPPERS = {
        "agente." => FCS::Ingestion::AgenteIntentMapper,
        "venue." => FCS::Ingestion::VenueExecutionMapper,
        "faucet." => FCS::Ingestion::FaucetIssuanceMapper
      }.freeze

      # @param source_event [Hash]
      # @return [Hash]
      # @raise [FCS::Error]
      def normalize!(source_event)
        validate_source_event_shape!(source_event)

        mapper_for(source_event).map!(source_event)
      end

      # @param source_events [Array<Hash>]
      # @return [Array<Hash>]
      # @raise [FCS::Error]
      def normalize_batch!(source_events)
        validate_source_events_shape!(source_events)

        source_events.map { |source_event| normalize!(source_event) }
      end

      private

      def validate_source_event_shape!(source_event)
        return if source_event.is_a?(Hash)

        raise_invalid!("source event must be an object", field: "sourceEvent")
      end

      def validate_source_events_shape!(source_events)
        return if source_events.is_a?(Array)

        raise_invalid!("source events must be an array", field: "sourceEvents")
      end

      def mapper_for(source_event)
        source = source_event.fetch("source", nil)
        unless source.is_a?(String) && !source.strip.empty?
          raise_invalid!("source event source must be a non-empty string", field: "sourceEvent.source")
        end

        _, mapper_klass = SOURCE_MAPPERS.find { |prefix, _klass| source.start_with?(prefix) }
        return mapper_klass.new if mapper_klass

        raise_invalid!("unsupported source for normalization pipeline", field: "sourceEvent.source")
      end

      def raise_invalid!(message, field:)
        raise FCS::Error.new(FCS::Errors::ERR_VALIDATION, message, details: {field: field})
      end
    end
  end
end
