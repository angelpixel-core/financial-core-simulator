# frozen_string_literal: true

module FCS
  module Ingestion
    # Detects duplicate and conflicting source events.
    #
    # @example
    #   guard = FCS::Ingestion::SourceEventIdempotencyGuard.new
    #   guard.classify!(event)
    class SourceEventIdempotencyGuard
      # Invariants:
      # 1) Identity key is [source, payload.externalId, payload.sequence].
      # 2) Same identity + same canonical payload => duplicate retry (not accepted twice).
      # 3) Same identity + different canonical payload => semantic collision (ERR_VALIDATION).
      def initialize
        @seen_fingerprints = {}
      end

      # @param event [Hash]
      # @return [Symbol] :accepted, :duplicate, or :collision
      # @raise [FCS::Error]
      def classify!(event)
        key = idempotency_key_for(event)
        fingerprint = FCS::Hashing::CanonicalJSON.dump(event)
        previous = @seen_fingerprints[key]

        if previous.nil?
          @seen_fingerprints[key] = fingerprint
          :accepted
        elsif previous == fingerprint
          :duplicate
        else
          :collision
        end
      end

      private

      def idempotency_key_for(event)
        payload = event.fetch("payload")
        external_id = payload["externalId"]
        sequence = payload["sequence"]

        unless external_id.is_a?(String) && !external_id.strip.empty? && !sequence.nil?
          raise FCS::Error.new(
            FCS::Errors::ERR_VALIDATION,
            "source event idempotency identity requires payload.externalId and payload.sequence",
            details: { field: "sourceEvent.idempotencyKey" }
          )
        end

        [event.fetch("source"), external_id.to_s, sequence.to_s]
      end
    end
  end
end
