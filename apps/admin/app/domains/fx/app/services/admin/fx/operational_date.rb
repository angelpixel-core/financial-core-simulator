# frozen_string_literal: true

require "time"

module Admin
  module Fx
    class OperationalDate
      DEFAULT_TIMEZONE = "UTC"

      def self.call(timestamp: nil, timezone: nil)
        new(timezone: timezone).call(timestamp: timestamp)
      end

      def initialize(timezone: nil, clock: Time, time_zone: ActiveSupport::TimeZone)
        @timezone = timezone || ENV.fetch("FCS_OPERATIONAL_TIMEZONE", DEFAULT_TIMEZONE)
        @clock = clock
        @time_zone = time_zone
      end

      def call(timestamp: nil)
        zone = resolve_zone
        time = timestamp.nil? ? @clock.current : parse_timestamp(timestamp)
        time.in_time_zone(zone).to_date
      end

      private

      def resolve_zone
        @time_zone[@timezone] || @time_zone[DEFAULT_TIMEZONE] || Time.zone
      end

      def parse_timestamp(value)
        case value
        when Time
          value
        when DateTime
          value.to_time
        when Integer
          Time.at(value)
        else
          Time.iso8601(value.to_s)
        end
      rescue ArgumentError
        raise ArgumentError, "Invalid operational timestamp"
      end
    end
  end
end
