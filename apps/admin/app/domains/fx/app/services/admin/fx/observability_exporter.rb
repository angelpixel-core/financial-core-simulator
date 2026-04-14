# frozen_string_literal: true

module Admin
  module Fx
    class ObservabilityExporter
      def self.call(snapshot:)
        new(snapshot: snapshot).call
      end

      def initialize(snapshot:)
        @snapshot = snapshot
      end

      def call
        {
          metrics: build_metrics,
          events: snapshot.fetch(:events, [])
        }
      end

      private

      attr_reader :snapshot

      def build_metrics
        range = snapshot.fetch(:range, {})
        source_counts = snapshot.fetch(:counts_by_source, [])
        failures = snapshot.fetch(:failures_by_code, [])

        metrics = []
        metrics.concat(source_metrics(source_counts, range))
        metrics.concat(failure_metrics(failures, range))
        metrics
      end

      def source_metrics(source_counts, range)
        source_counts.flat_map do |entry|
          base_tags = {
            source_id: entry[:source_id],
            source_code: entry[:source_code],
            source_name: entry[:source_name],
            range_days: range[:days]
          }

          [
            metric_item("fx_ingestion_success_total", entry[:success], base_tags),
            metric_item("fx_ingestion_failed_total", entry[:failed], base_tags),
            metric_item("fx_ingestion_running_total", entry[:running], base_tags),
            metric_item("fx_ingestion_pending_total", entry[:pending], base_tags)
          ]
        end
      end

      def failure_metrics(failures, range)
        failures.map do |entry|
          metric_item(
            "fx_ingestion_failure_total",
            entry[:count],
            {
              error_code: entry[:error_code],
              severity: entry[:severity],
              range_days: range[:days]
            }
          )
        end
      end

      def metric_item(name, value, tags)
        {
          name: name,
          value: value.to_i,
          tags: tags.compact
        }
      end
    end
  end
end
