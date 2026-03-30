# frozen_string_literal: true

require 'bigdecimal'

module Admin
  module Dashboard
    class PnlTimelineAggregator
      def initialize(points:)
        @points = Array(points)
      end

      def call
        normalized = @points.filter_map { |point| normalize_point(point) }
        return [] if normalized.empty?

        grouped = normalized.group_by { |point| point.fetch(:date) }
        grouped.keys.sort.map do |date|
          day_points = grouped.fetch(date)
          last_point = day_points.max_by { |point| point.fetch(:timestamp) }

          {
            timestamp: date,
            realized_pnl: last_point.fetch(:realized_pnl).to_f,
            unrealized_pnl: last_point.fetch(:unrealized_pnl).to_f,
            total_pnl: last_point.fetch(:total_pnl).to_f
          }
        end
      end

      private

      def normalize_point(point)
        return nil unless point.is_a?(Hash)

        timestamp_value = point['timestamp'] || point[:timestamp]
        timestamp = parse_time(timestamp_value)
        return nil if timestamp.nil?

        realized = parse_decimal(point['realized_pnl'] || point[:realized_pnl])
        unrealized = parse_decimal(point['unrealized_pnl'] || point[:unrealized_pnl])
        total = parse_decimal(point['total_pnl'] || point[:total_pnl])
        return nil if realized.nil? || unrealized.nil? || total.nil?

        {
          date: timestamp.utc.to_date.iso8601,
          timestamp: timestamp,
          realized_pnl: realized,
          unrealized_pnl: unrealized,
          total_pnl: total
        }
      end

      def parse_time(raw)
        return nil if raw.nil?

        raw_string = raw.to_s.strip
        return nil if raw_string.empty?

        Time.zone.parse(raw_string)
      rescue ArgumentError
        nil
      end

      def parse_decimal(value)
        return nil if value.nil?

        BigDecimal(value.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
