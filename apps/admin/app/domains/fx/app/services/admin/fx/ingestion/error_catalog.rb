# frozen_string_literal: true

module Admin
  module Fx
    module Ingestion
      class ErrorCatalog
        Entry = Struct.new(
          :code,
          :severity,
          :message,
          :user_message_key,
          :action_hint_key,
          :retryable,
          keyword_init: true
        )

        ENTRIES = {
          "adapter_missing" => Entry.new(
            code: "adapter_missing",
            severity: "error",
            message: "No adapter found for FX source",
            user_message_key: "admin.fx.ingestion_errors.adapter_missing.message",
            action_hint_key: "admin.fx.ingestion_errors.adapter_missing.action_hint",
            retryable: false
          ),
          "http_error" => Entry.new(
            code: "http_error",
            severity: "error",
            message: "HTTP request failed",
            user_message_key: "admin.fx.ingestion_errors.http_error.message",
            action_hint_key: "admin.fx.ingestion_errors.http_error.action_hint",
            retryable: true
          ),
          "validation_failed" => Entry.new(
            code: "validation_failed",
            severity: "warning",
            message: "Payload schema validation failed",
            user_message_key: "admin.fx.ingestion_errors.validation_failed.message",
            action_hint_key: "admin.fx.ingestion_errors.validation_failed.action_hint",
            retryable: false
          ),
          "mapping_failed" => Entry.new(
            code: "mapping_failed",
            severity: "warning",
            message: "Payload mapping failed",
            user_message_key: "admin.fx.ingestion_errors.mapping_failed.message",
            action_hint_key: "admin.fx.ingestion_errors.mapping_failed.action_hint",
            retryable: false
          ),
          "job_error" => Entry.new(
            code: "job_error",
            severity: "error",
            message: "FX ingestion job failed",
            user_message_key: "admin.fx.ingestion_errors.job_error.message",
            action_hint_key: "admin.fx.ingestion_errors.job_error.action_hint",
            retryable: true
          )
        }.freeze

        def self.fetch(code)
          ENTRIES[code.to_s] || fallback(code)
        end

        def self.details_for(code)
          entry = fetch(code)
          {
            error_code: entry.code,
            severity: entry.severity,
            message: entry.message,
            user_message_key: entry.user_message_key,
            action_hint_key: entry.action_hint_key,
            retryable: entry.retryable
          }
        end

        def self.fallback(code)
          Entry.new(
            code: code.to_s,
            severity: "error",
            message: "Unknown ingestion error",
            user_message_key: "admin.fx.ingestion_errors.unknown.message",
            action_hint_key: "admin.fx.ingestion_errors.unknown.action_hint",
            retryable: false
          )
        end
      end
    end
  end
end
