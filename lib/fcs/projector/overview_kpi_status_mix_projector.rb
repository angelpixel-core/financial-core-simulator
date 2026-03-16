# frozen_string_literal: true

module FCS
  module Projector
    # Projects lifecycle KPI and status mix data.
    class OverviewKpiStatusMixProjector
      SUPPORTED_EVENT_TYPE = "RUN_LIFECYCLE_NORMALIZED"
      SUPPORTED_STATUSES = %w[queued running succeeded failed].freeze

      def initialize
        @run_statuses = {}
      end

      def apply!(event)
        validate_event_shape!(event)
        validate_event_type!(event)

        payload = event.fetch("payload")
        run_id = payload.fetch("runId")
        status = payload.fetch("status")

        validate_non_empty_string!(run_id, field: "event.payload.runId")
        validate_supported_status!(status)

        @run_statuses[run_id] = status
        true
      end

      def read_model
        status_mix = base_status_mix
        @run_statuses.each_value { |status| status_mix[status] += 1 }

        {
          "overviewKpi" => status_mix.dup,
          "statusMix" => status_mix
        }
      end

      private

      def base_status_mix
        {
          "queued" => 0,
          "running" => 0,
          "succeeded" => 0,
          "failed" => 0
        }
      end

      def validate_event_shape!(event)
        return if event.is_a?(Hash)

        raise_invalid!("projector event must be an object", field: "event")
      end

      def validate_event_type!(event)
        event_type = event.fetch("eventType", nil)
        return if event_type == SUPPORTED_EVENT_TYPE

        raise_invalid!("unsupported projector event type", field: "event.eventType")
      end

      def validate_non_empty_string!(value, field:)
        return if value.is_a?(String) && !value.strip.empty?

        raise_invalid!("projector field must be a non-empty string", field: field)
      end

      def validate_supported_status!(status)
        return if SUPPORTED_STATUSES.include?(status)

        raise_invalid!("unsupported lifecycle status", field: "event.payload.status")
      end

      def raise_invalid!(message, field:)
        raise FCS::Error.new(FCS::Errors::ERR_VALIDATION, message, details: { field: field })
      end
    end
  end
end
