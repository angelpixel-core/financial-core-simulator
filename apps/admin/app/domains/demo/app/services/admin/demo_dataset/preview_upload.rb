# frozen_string_literal: true

module Admin
  module DemoDataset
    class PreviewUpload
      def initialize(parser: Admin::DemoDataset::ExcelToInputParser)
        @parser = parser
      end

      def call(file_path:, timeline_enabled:)
        result = @parser.call(file_path: file_path, timeline_enabled: timeline_enabled)
        input = result.input

        {
          state: result.valid? ? :success : :invalid,
          summary: build_summary(input),
          sample_rows: input.is_a?(Hash) ? Array(fetch_value(input, :trades)) : [],
          errors: result.errors
        }
      end

      private

      def build_summary(input)
        return nil unless input.is_a?(Hash)

        fee_model = fetch_value(input, :feeModel)
        {
          trades_count: Array(fetch_value(input, :trades)).size,
          accounts_count: Array(fetch_value(input, :accounts)).size,
          markets_count: Array(fetch_value(input, :markets)).size,
          schema_version: fetch_value(input, :schemaVersion),
          fee_enabled: fee_model.is_a?(Hash) ? (fee_model[:enabled] || fee_model['enabled']) : nil
        }
      end

      def fetch_value(input, key)
        return input[key] if input.key?(key)

        input[key.to_s]
      end
    end
  end
end
