# frozen_string_literal: true

module FCS
  module Application
    module Base
      class Event
        attr_reader :event_type, :data, :metadata

        def self.allowed_types
          %w[
            fx_rate.ingested
            fx_rate.validation_failed
            fx_rate.persisted
            fx_rate.fetch_failed
            fx_rate.mapping_failed
          ]
        end

        def initialize(event_type:, data: {}, metadata: {})
          raise ArgumentError, "event_type is required" if event_type.nil?

          @event_type = event_type.to_s
          @data = data || {}
          @metadata = metadata || {}

          return if self.class.allowed_types.include?(@event_type)

          raise ArgumentError, "event_type is not allowed"
        end

        def to_h
          {
            event_type: event_type,
            data: data,
            metadata: metadata
          }
        end
      end
    end
  end
end
