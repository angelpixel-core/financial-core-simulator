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
        counts_by_source_totals = build_counts_by_source_totals(counts_by_source)
        failures_by_code_totals = build_failures_by_code_totals(failures_by_code)
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
          counts_by_source_totals: counts_by_source_totals,
          failures_by_code: failures_by_code,
          failures_by_code_totals: failures_by_code_totals,
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
        grouped = ingestions.group_by do |ingestion|
          [ingestion.source_id, ingestion.status, time_bucket_for(ingestion.created_at)]
        end

        sources.flat_map do |source|
          buckets = grouped.keys.filter_map do |source_key, _status, bucket|
            bucket if source_key == source.id
          end.uniq

          buckets.map do |bucket|
            {
              source_id: source.id,
              source_code: source.code,
              source_name: source.name,
              time_bucket: bucket,
              success: grouped[[source.id, "success", bucket]]&.size.to_i,
              failed: grouped[[source.id, "failed", bucket]]&.size.to_i,
              running: grouped[[source.id, "running", bucket]]&.size.to_i,
              pending: grouped[[source.id, "pending", bucket]]&.size.to_i
            }
          end
        end
      end

      def build_failures_by_code(ingestions)
        failed = ingestions.select { |ingestion| ingestion.status == "failed" }
        grouped = failed.group_by do |ingestion|
          [ingestion.error_code, time_bucket_for(ingestion.created_at)]
        end

        grouped.map do |(error_code, bucket), items|
          {
            error_code: error_code,
            severity: Admin::Fx::Ingestion::ErrorCatalog.details_for(error_code)[:severity],
            time_bucket: bucket,
            count: items.size
          }
        end
      end

      def build_counts_by_source_totals(entries)
        entries.group_by { |entry| [entry[:source_id], entry[:source_code], entry[:source_name]] }
          .map do |(source_id, source_code, source_name), grouped|
            {
              source_id: source_id,
              source_code: source_code,
              source_name: source_name,
              success: grouped.sum { |entry| entry[:success].to_i },
              failed: grouped.sum { |entry| entry[:failed].to_i },
              running: grouped.sum { |entry| entry[:running].to_i },
              pending: grouped.sum { |entry| entry[:pending].to_i }
            }
          end
          .sort_by { |entry| entry[:source_name].to_s }
      end

      def build_failures_by_code_totals(entries)
        entries.group_by { |entry| entry[:error_code] }
          .map do |error_code, grouped|
            {
              error_code: error_code,
              severity: grouped.first[:severity],
              count: grouped.sum { |entry| entry[:count].to_i }
            }
          end
          .sort_by { |entry| -entry[:count].to_i }
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
              time_bucket: time_bucket_for(event.created_at),
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

      def time_bucket_for(timestamp)
        timestamp.utc.to_date.iso8601
      end
    end
  end
end
