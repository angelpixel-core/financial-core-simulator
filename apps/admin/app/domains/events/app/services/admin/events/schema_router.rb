# frozen_string_literal: true

module Admin
  module Events
    class SchemaRouter
      SCHEMA_VERSION = '1.0'

      EVENT_TYPE_MAP = {
        'runs.execution.completed' => 'RUN_LIFECYCLE_NORMALIZED',
        'runs.execution.failed' => 'RUN_LIFECYCLE_NORMALIZED',
        'fx.rate.updated' => 'RISK_SNAPSHOT_NORMALIZED'
      }.freeze

      def initialize(projection_router: FCS::Projector::EventProjectionRouter.new)
        @projection_router = projection_router
      end

      def route(event_name:, payload:, occurred_at: Time.now.utc)
        event_type = EVENT_TYPE_MAP.fetch(event_name, 'RUN_LIFECYCLE_NORMALIZED')
        projection_keys = Array(@projection_router.projections_for(event_type))

        {
          schemaVersion: SCHEMA_VERSION,
          eventName: event_name,
          eventType: event_type,
          occurredAt: occurred_at.utc.iso8601,
          payload: payload,
          projections: projection_keys
        }
      end
    end
  end
end
