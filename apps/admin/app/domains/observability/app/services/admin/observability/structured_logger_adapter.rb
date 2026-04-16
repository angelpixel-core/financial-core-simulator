# frozen_string_literal: true

require "json"

module Admin
  module Observability
    class StructuredLoggerAdapter
      def initialize(logger: Rails.logger)
        @logger = logger
      end

      def info(event:, payload: {}, tags: {})
        emit(level: :info, event: event, payload: payload, tags: tags)
      end

      def error(event:, payload: {}, tags: {})
        emit(level: :error, event: event, payload: payload, tags: tags)
      end

      private

      def emit(level:, event:, payload:, tags:)
        entry = {
          event: event,
          tags: tags,
          payload: payload,
          timestamp: Time.now.utc.iso8601
        }
        @logger.public_send(level, JSON.generate(entry))
        entry
      end
    end
  end
end
