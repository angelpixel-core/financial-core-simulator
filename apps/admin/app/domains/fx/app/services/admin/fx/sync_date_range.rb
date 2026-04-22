# frozen_string_literal: true

module Admin
  module Fx
    class SyncDateRange
      Result = Struct.new(:valid?, :date_from, :date_to, :max_date_to, :error_message_key, keyword_init: true)

      ARGENTINA_TIMEZONE = "America/Argentina/Buenos_Aires"
      DEFAULT_WINDOW_DAYS = 30
      DEFAULT_MAX_WINDOW_DAYS = 90
      DEFAULT_BCRA_OPEN_HOUR = 10

      def self.resolve(source:, date_from_param:, date_to_param:, now: Time.current)
        new(source: source, now: now).resolve(date_from_param: date_from_param, date_to_param: date_to_param)
      end

      def self.defaults(source:, now: Time.current)
        new(source: source, now: now).defaults
      end

      def initialize(source:, now: Time.current)
        @source = source
        @now = now
      end

      def resolve(date_from_param:, date_to_param:)
        fallback = defaults
        date_from = parse_date(date_from_param) || fallback.date_from
        date_to = parse_date(date_to_param) || fallback.date_to

        return invalid(fallback, "admin.fx.history.sync.invalid_date_range") if date_from > date_to
        return invalid(fallback, "admin.fx.history.sync.invalid_date_range") if date_to > fallback.max_date_to

        if (date_to - date_from).to_i + 1 > max_window_days
          return invalid(fallback, "admin.fx.history.sync.range_too_wide")
        end

        Result.new(valid?: true, date_from: date_from, date_to: date_to, max_date_to: fallback.max_date_to)
      end

      def defaults
        max_date_to = max_date_to_for_source
        date_from = max_date_to - (default_window_days - 1)
        Result.new(valid?: true, date_from: date_from, date_to: max_date_to, max_date_to: max_date_to)
      end

      private

      attr_reader :source, :now

      def source_code
        source&.code.to_s.upcase
      end

      def max_date_to_for_source
        return now.to_date unless source_code == "BCRA"

        art_now = now.in_time_zone(ARGENTINA_TIMEZONE)
        bank_open_hour = ENV.fetch("BCRA_BANK_OPEN_HOUR_ART", DEFAULT_BCRA_OPEN_HOUR).to_i
        return art_now.to_date if art_now.hour >= bank_open_hour

        art_now.to_date - 1
      end

      def default_window_days
        value = ENV.fetch("FX_SYNC_DEFAULT_RANGE_DAYS", DEFAULT_WINDOW_DAYS).to_i
        value.positive? ? value : DEFAULT_WINDOW_DAYS
      end

      def max_window_days
        value = ENV.fetch("FX_SYNC_MAX_RANGE_DAYS", DEFAULT_MAX_WINDOW_DAYS).to_i
        value.positive? ? value : DEFAULT_MAX_WINDOW_DAYS
      end

      def parse_date(value)
        return nil if value.blank?

        Date.iso8601(value.to_s)
      rescue ArgumentError
        nil
      end

      def invalid(fallback, message_key)
        Result.new(
          valid?: false,
          date_from: fallback.date_from,
          date_to: fallback.date_to,
          max_date_to: fallback.max_date_to,
          error_message_key: message_key
        )
      end
    end
  end
end
