# frozen_string_literal: true

require "date"
require "time"

module FCS
  module Projector
    # Projects 14-day run trends and latest run metadata.
    class TrendLatestRunProjector
      SUPPORTED_EVENT_TYPE = "RUN_LIFECYCLE_NORMALIZED"
      SUPPORTED_STATUSES = %w[queued running succeeded failed].freeze

      def initialize(today: Date.today)
        @today = today
        @event_counts_by_day = Hash.new(0)
        @latest_run = nil
        @latest_run_occurred_at = nil
      end

      def apply!(event)
        validate_event_shape!(event)
        validate_event_type!(event)

        payload = event.fetch("payload")
        run_id = payload.fetch("runId")
        status = payload.fetch("status")
        correlation_id = event.fetch("correlationId")
        occurred_at = parse_occurred_at!(event.fetch("occurredAt"))

        validate_non_empty_string!(run_id, field: "event.payload.runId")
        validate_supported_status!(status)
        validate_non_empty_string!(correlation_id, field: "event.correlationId")

        day_key = occurred_at.to_date.strftime("%m-%d")
        @event_counts_by_day[day_key] += 1

        if @latest_run_occurred_at.nil? || occurred_at > @latest_run_occurred_at
          @latest_run_occurred_at = occurred_at
          @latest_run = {
            "runId" => run_id,
            "status" => status,
            "correlationId" => correlation_id,
            "occurredAt" => event.fetch("occurredAt")
          }
        end

        true
      end

      def read_model
        {
          "runsTrend14d" => runs_trend_14d,
          "latestRun" => @latest_run
        }
      end

      private

      def runs_trend_14d
        start_date = @today - 13

        (start_date..@today).map do |day|
          key = day.strftime("%m-%d")
          {
            "day" => key,
            "count" => @event_counts_by_day[key]
          }
        end
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

      def parse_occurred_at!(occurred_at)
        validate_non_empty_string!(occurred_at, field: "event.occurredAt")
        Time.iso8601(occurred_at)
      rescue ArgumentError
        raise_invalid!("projector occurredAt must be ISO8601", field: "event.occurredAt")
      end

      def raise_invalid!(message, field:)
        raise FCS::Error.new(FCS::Errors::ERR_VALIDATION, message, details: { field: field })
      end
    end
  end
end
