# frozen_string_literal: true

module Admin
  module Fx
    module ObservabilityContract
      # Shape of the observability snapshot payload.
      #
      # range: { from: String (ISO8601), to: String (ISO8601), days: Integer }
      # summary: { total: Integer, success: Integer, failed: Integer, running: Integer, pending: Integer }
      # sources: [
      #   { source_id: Integer, source_code: String, source_name: String,
      #     status: String, error_code: String|nil, updated_at: String|nil }
      # ]
      # counts_by_source: [
      #   { source_id: Integer, source_code: String, source_name: String, time_bucket: String,
      #     success: Integer, failed: Integer, running: Integer, pending: Integer }
      # ]
      # counts_by_source_totals: [
      #   { source_id: Integer, source_code: String, source_name: String,
      #     success: Integer, failed: Integer, running: Integer, pending: Integer }
      # ]
      # failures_by_code: [
      #   { error_code: String, severity: String, time_bucket: String, count: Integer }
      # ]
      # failures_by_code_totals: [
      #   { error_code: String, severity: String, count: Integer }
      # ]
      # events: [
      #   { event_type: String, created_at: String, time_bucket: String, error_code: String|nil,
      #     severity: String|nil, source_id: Integer|nil, source_code: String|nil,
      #     ingestion_id: Integer|nil }
      # ]
      def self.empty(range_from:, range_to:, days:)
        {
          range: {
            from: range_from,
            to: range_to,
            days: days
          },
          summary: {
            total: 0,
            success: 0,
            failed: 0,
            running: 0,
            pending: 0
          },
          sources: [],
          counts_by_source: [],
          counts_by_source_totals: [],
          failures_by_code: [],
          failures_by_code_totals: [],
          events: []
        }
      end
    end
  end
end
