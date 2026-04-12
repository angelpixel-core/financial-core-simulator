# frozen_string_literal: true

module Admin
  module Fx
    module Ingestion
      class EventEmitter
        def initialize(result_class: Result, event_class: FCS::Application::Base::Event)
          @result_class = result_class
          @event_class = event_class
        end

        def emit(event_type:, data: {}, metadata: {})
          event = event_class.new(event_type: event_type, data: data, metadata: metadata)
          record = FxRateEvent.create!(event.to_h)

          result_class.success(data: {event_id: record.event_id}, metadata: {event_type: event.event_type})
        rescue ArgumentError => e
          result_class.failure(error_code: "event_invalid", context: {message: e.message, event_type: event_type})
        rescue => e
          result_class.failure(error_code: "event_persist_failed", context: {message: e.message, event_type: event_type})
        end

        private

        attr_reader :result_class, :event_class
      end
    end
  end
end
