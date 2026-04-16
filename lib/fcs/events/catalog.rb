# frozen_string_literal: true

module FCS
  module Events
    class Catalog
      DEFAULT_SCHEMA_VERSION = "1.0"
      DEFAULT_EVENT_VERSION = "1.0"

      REGISTRY = {
        "runs.execution.completed" => {
          event_type: "RUN_LIFECYCLE_NORMALIZED",
          schema_version: DEFAULT_SCHEMA_VERSION,
          event_version: DEFAULT_EVENT_VERSION
        },
        "runs.execution.failed" => {
          event_type: "RUN_LIFECYCLE_NORMALIZED",
          schema_version: DEFAULT_SCHEMA_VERSION,
          event_version: DEFAULT_EVENT_VERSION
        },
        "fx.rate.updated" => {
          event_type: "RISK_SNAPSHOT_NORMALIZED",
          schema_version: DEFAULT_SCHEMA_VERSION,
          event_version: DEFAULT_EVENT_VERSION
        }
      }.freeze

      FALLBACK_EVENT = {
        event_type: "RUN_LIFECYCLE_NORMALIZED",
        schema_version: DEFAULT_SCHEMA_VERSION,
        event_version: DEFAULT_EVENT_VERSION
      }.freeze

      def fetch(event_name)
        metadata = REGISTRY.fetch(event_name.to_s, FALLBACK_EVENT)

        {
          event_name: event_name.to_s,
          event_type: metadata.fetch(:event_type),
          schema_version: metadata.fetch(:schema_version),
          event_version: metadata.fetch(:event_version)
        }
      end
    end
  end
end
