# frozen_string_literal: true

module FCS
  module Projector
    # Routes normalized events to projection keys.
    #
    # @example
    #   router = FCS::Projector::EventProjectionRouter.new
    #   router.projections_for("RUN_LIFECYCLE_NORMALIZED")
    class EventProjectionRouter
      DEFAULT_ROUTES = {
        "RUN_LIFECYCLE_NORMALIZED" => %w[overview trend],
        "ACCOUNT_TOTALS_NORMALIZED" => ["topAccountsRisk"],
        "RISK_SNAPSHOT_NORMALIZED" => ["topAccountsRisk"]
      }.freeze

      # @param routes [Hash{String => Array<String>}]
      def initialize(routes: DEFAULT_ROUTES)
        @routes = normalize_routes!(routes)
      end

      # Returns projection keys for the given event type.
      #
      # @param event_type [String]
      # @return [Array<String>, nil]
      def projections_for(event_type)
        @routes.fetch(event_type, nil)
      end

      private

      def normalize_routes!(routes)
        unless routes.is_a?(Hash) && !routes.empty?
          raise_invalid!("event projection routes must be a non-empty hash", field: "eventProjectionRouter.routes")
        end

        routes.each_with_object({}) do |(event_type, projection_keys), normalized|
          validate_non_empty_string!(event_type, field: "eventProjectionRouter.routes.eventType")

          unless projection_keys.is_a?(Array) && !projection_keys.empty?
            raise_invalid!("event projection routes must map to a non-empty array",
              field: "eventProjectionRouter.routes.#{event_type}")
          end

          normalized[event_type] = projection_keys.map do |projection_key|
            validate_non_empty_string!(projection_key, field: "eventProjectionRouter.routes.#{event_type}.projection")
            projection_key
          end
        end
      end

      def validate_non_empty_string!(value, field:)
        return if value.is_a?(String) && !value.strip.empty?

        raise_invalid!("event projection router field must be a non-empty string", field: field)
      end

      def raise_invalid!(message, field:)
        raise FCS::Error.new(FCS::Errors::ERR_VALIDATION, message, details: {field: field})
      end
    end
  end
end
