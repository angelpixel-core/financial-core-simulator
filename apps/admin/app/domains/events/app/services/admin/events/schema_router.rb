# frozen_string_literal: true

require "securerandom"

module Admin
  module Events
    class SchemaRouter
      def initialize(
        projection_router: FCS::Projector::EventProjectionRouter.new,
        event_catalog: FCS::Events::Catalog.new
      )
        @projection_router = projection_router
        @event_catalog = event_catalog
      end

      def route(event_name:, payload:, occurred_at: Time.now.utc, correlation_id: nil, source: "admin.events")
        event = @event_catalog.fetch(event_name)
        event_type = event.fetch(:event_type)
        projection_keys = Array(@projection_router.projections_for(event_type))
        correlation = correlation_id.to_s.presence || payload[:runId].presence || payload["runId"].presence ||
          SecureRandom.uuid

        {
          schemaVersion: event.fetch(:schema_version),
          eventVersion: event.fetch(:event_version),
          eventName: event_name,
          eventType: event_type,
          source: source,
          correlationId: correlation,
          occurredAt: occurred_at.utc.iso8601,
          payload: payload,
          projections: projection_keys
        }
      end
    end
  end
end
