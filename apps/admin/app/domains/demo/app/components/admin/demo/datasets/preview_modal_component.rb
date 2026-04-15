# frozen_string_literal: true

module Admin
  module Demo
    module Datasets
      class PreviewModalComponent < ViewComponent::Base
        def initialize(state:, summary: nil, sample_rows: [], errors: [], file_name: nil, sample_rows_truncated: false,
          errors_truncated: false)
          @state = state&.to_sym
          @summary = summary
          @sample_rows = sample_rows
          @errors = errors
          @file_name = file_name
          @sample_rows_truncated = sample_rows_truncated
          @errors_truncated = errors_truncated
        end

        def loading?
          @state == :loading
        end

        def success?
          @state == :success
        end

        def invalid?
          @state == :invalid
        end

        def error?
          @state == :error
        end

        def empty?
          success? && sample_rows.empty?
        end

        def summary_items
          return [] unless @summary.is_a?(Hash)

          items = [
            {label: t("admin.overview.dataset.preview.trades_label"), value: summary_value(:trades_count)},
            {label: t("admin.overview.dataset.preview.accounts_label"), value: summary_value(:accounts_count)},
            {label: t("admin.overview.dataset.preview.markets_label"), value: summary_value(:markets_count)},
            {label: t("admin.overview.dataset.preview.schema_label"), value: summary_value(:schema_version)}
          ]

          fee_value = summary_value(:fee_enabled)
          unless fee_value.nil?
            items << {
              label: t("admin.overview.dataset.preview.fee_label"),
              value: fee_value ? t("admin.overview.dataset.preview.fee_enabled") : t("admin.overview.dataset.preview.fee_disabled")
            }
          end

          items
        end

        def sample_rows
          Array(@sample_rows)
        end

        def error_items
          Array(@errors).sort_by do |error|
            line = error[:line] || error["line"] || 0
            code = error[:code] || error["code"] || ""
            [line, code]
          end
        end

        attr_reader :file_name

        def sample_rows_truncated?
          @sample_rows_truncated
        end

        def errors_truncated?
          @errors_truncated
        end

        def row_value(row, key)
          return nil unless row.is_a?(Hash)

          row[key] || row[key.to_s]
        end

        private

        def summary_value(key)
          return nil unless @summary.is_a?(Hash)

          @summary[key] || @summary[key.to_s]
        end
      end
    end
  end
end
