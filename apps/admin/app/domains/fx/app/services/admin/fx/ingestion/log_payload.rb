# frozen_string_literal: true

module Admin
  module Fx
    module Ingestion
      class LogPayload
        def self.call(ingestion:, source:, message:, error_code: nil, severity: nil, extra: {})
          new(ingestion: ingestion, source: source, message: message, error_code: error_code,
            severity: severity, extra: extra).call
        end

        def initialize(ingestion:, source:, message:, error_code:, severity:, extra: {})
          @ingestion = ingestion
          @source = source
          @message = message
          @error_code = error_code
          @severity = severity
          @extra = extra || {}
        end

        def call
          {
            message: message,
            ingestion_id: ingestion&.id,
            source_code: source&.code,
            error_code: error_code,
            severity: severity
          }.merge(base_context).merge(extra)
        end

        private

        attr_reader :ingestion, :source, :message, :error_code, :severity, :extra

        def base_context
          {
            correlation_id: ingestion&.correlation_id,
            source_id: source&.id
          }
        end
      end
    end
  end
end
