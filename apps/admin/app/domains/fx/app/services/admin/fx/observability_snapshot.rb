# frozen_string_literal: true

module Admin
  module Fx
    class ObservabilitySnapshot
      DEFAULT_DAYS = 7

      def self.call(source_id: nil, days: DEFAULT_DAYS)
        new(source_id: source_id, days: days).call
      end

      def initialize(source_id:, days:)
        @source_id = source_id
        @days = normalize_days(days)
      end

      def call
        range_from = range_start
        range_to = range_end

        sources = load_sources
        if sources.empty?
          return ObservabilityContract.empty(range_from: range_from.iso8601, range_to: range_to.iso8601,
            days: days)
        end

        ingestions = FxRateIngestion.where(source_id: sources.map(&:id))
          .where(created_at: range_from..range_to)

        summary = build_summary(ingestions)
        counts_by_source = build_counts_by_source(ingestions, sources)
        failures_by_code = build_failures_by_code(ingestions)
        events = build_events(range_from: range_from, range_to: range_to, sources: sources)
        latest_statuses = build_latest_statuses(sources)

        {
          range: {
            from: range_from.iso8601,
            to: range_to.iso8601,
            days: days
          },
          summary: summary,
          sources: latest_statuses,
          counts_by_source: counts_by_source,
          failures_by_code: failures_by_code,
          events: events
        }
      end

      private

      attr_reader :source_id, :days

      def normalize_days(value)
        number = value.to_i
        number.positive? ? number : DEFAULT_DAYS
      end

      def range_start
        Time.current - days.days
      end

      def range_end
        Time.current
      end

      def load_sources
        scope = FxRateSource.order(:name)
        scope = scope.where(id: source_id) if source_id.present?
        scope.to_a
      end

      def build_summary(ingestions)
        total = ingestions.count
        counts = ingestions.group(:status).count
        {
          total: total,
          success: counts["success"].to_i,
          failed: counts["failed"].to_i,
          running: counts["running"].to_i,
          pending: counts["pending"].to_i
        }
      end

      def build_counts_by_source(ingestions, sources)
        counts = ingestions.group(:source_id, :status).count
        sources.map do |source|
          {
            source_id: source.id,
            source_code: source.code,
            source_name: source.name,
            success: counts[[source.id, "success"]].to_i,
            failed: counts[[source.id, "failed"]].to_i,
            running: counts[[source.id, "running"]].to_i,
            pending: counts[[source.id, "pending"]].to_i
          }
        end
      end

      def build_failures_by_code(ingestions)
        ingestions.where(status: "failed")
          .group(:error_code)
          .count
          .map do |error_code, count|
            {
              error_code: error_code,
              severity: Admin::Fx::Ingestion::ErrorCatalog.details_for(error_code)[:severity],
              count: count
            }
          end
      end

      def build_events(range_from:, range_to:, sources:)
        source_ids = sources.map(&:id).map(&:to_s)
        FxRateEvent.where(created_at: range_from..range_to)
          .where("data ->> 'source_id' IN (?) OR metadata ->> 'source_id' IN (?)", source_ids, source_ids)
          .order(created_at: :desc)
          .limit(20)
          .map do |event|
            {
              event_type: event.event_type,
              created_at: event.created_at.iso8601,
              error_code: event.data["error_code"],
              severity: event.data["severity"],
              source_id: (event.data["source_id"] || event.metadata["source_id"])&.to_i,
              source_code: event.data["source_code"],
              ingestion_id: (event.metadata["ingestion_id"] || event.data["ingestion_id"])&.to_i
            }
          end
      end

      def build_latest_statuses(sources)
        latest = FxRateIngestion.where(source_id: sources.map(&:id))
          .order(created_at: :desc)
          .group_by(&:source_id)
          .transform_values(&:first)

        sources.map do |source|
          ingestion = latest[source.id]
          {
            source_id: source.id,
            source_code: source.code,
            source_name: source.name,
            status: ingestion&.status,
            error_code: ingestion&.error_code,
            updated_at: ingestion&.updated_at&.iso8601
          }
        end
      end
    end
  end
end
