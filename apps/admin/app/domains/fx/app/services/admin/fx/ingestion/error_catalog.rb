# typed: true
# frozen_string_literal: true

require "sorbet-runtime"

module Admin
  module Fx
    module Ingestion
      class ErrorCatalog
        extend T::Sig

        class Entry < T::Struct
          const :code, String
          const :severity, String
          const :message, String
          const :user_message_key, String
          const :action_hint_key, String
          const :retryable, T::Boolean
        end

        ENTRIES = T.let({
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
        }.freeze, T::Hash[String, Entry])

        sig { params(code: T.untyped).returns(Entry) }
        def self.fetch(code)
          ENTRIES[code.to_s] || fallback(code)
        end

        # @param code [String]
        # @return [Hash]
        sig { params(code: T.untyped).returns(T::Hash[Symbol, T.untyped]) }
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

        sig { params(code: T.untyped).returns(Entry) }
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
