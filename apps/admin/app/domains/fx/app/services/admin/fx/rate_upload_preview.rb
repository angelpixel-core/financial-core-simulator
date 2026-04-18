# frozen_string_literal: true

require "roo"

module Admin
  module Fx
    class RateUploadPreview
      Result = Struct.new(:valid?, :errors, :sample_rows, :total_rows, keyword_init: true)

      REQUIRED_HEADERS = RateUploadImporter::REQUIRED_HEADERS
      MAX_PREVIEW_ROWS = 25

      def self.call(file_path:)
        new(file_path: file_path).call
      end

      def initialize(file_path:)
        @file_path = file_path
        @errors = []
        @sample_rows = []
        @total_rows = 0
      end

      def call
        workbook = Roo::Spreadsheet.open(@file_path)
        sheet_names = workbook.sheets
        if sheet_names.empty?
          register_error(1, "EMPTY_FILE", "No worksheets found")
          return result(false)
        end

        if sheet_names.size > 1
          register_error(1, "MULTIPLE_SHEETS", "Template must include a single worksheet")
          return result(false)
        end

        sheet_name = sheet_names.first
        sheet = workbook.sheet(sheet_name)
        headers = Array(sheet.row(1)).map { |value| normalize_header(value) }
        validate_headers!(headers, sheet_name)
        return result(false) if @errors.any?

        return result(true) if sheet.last_row.nil? || sheet.last_row < 2

        (2..sheet.last_row).each do |line|
          row = headers.zip(sheet.row(line)).to_h
          next if row.values.all?(&:blank?)

          parse_row(row, line, sheet_name: sheet_name)
        end

        result(@errors.empty?)
      rescue => e
        register_error(1, "PREVIEW_FAILED", e.message)
        result(false)
      end

      private

      def validate_headers!(headers, sheet_name)
        missing = REQUIRED_HEADERS - headers
        return if missing.empty?

        register_error(1, "INVALID_HEADERS", "Sheet #{sheet_name} missing columns: #{missing.join(", ")}")
      end

      def normalize_header(value)
        value.to_s.strip.downcase.gsub(/\s+/, "_")
      end

      def parse_row(row, line, sheet_name:)
        return if row["rate"].blank?

        line_label = "#{sheet_name}:#{line}"
        operational_date = parse_date(row["operational_date"])
        base_currency = row["base_currency"].to_s.strip.upcase
        quote_currency = row["quote_currency"].to_s.strip.upcase
        rate = parse_rate(row["rate"])

        if operational_date.nil?
          register_error(line_label, "INVALID_DATE", "Invalid operational date")
          return
        end

        if base_currency.empty? || quote_currency.empty?
          register_error(line_label, "MISSING_FIELDS", "Missing required currency values")
          return
        end

        unless base_currency.match?(FxDailyRate::CURRENCY_CODE_FORMAT) && quote_currency.match?(FxDailyRate::CURRENCY_CODE_FORMAT)
          register_error(line_label, "INVALID_PAIR", "Invalid currency code format")
          return
        end

        unless supported_pair?(base_currency, quote_currency)
          register_error(line_label, "UNSUPPORTED_PAIR", "Unsupported FX pair")
          return
        end

        if rate.nil?
          register_error(line_label, "MISSING_FIELDS", "Missing required values")
          return
        end

        if rate <= 0
          register_error(line_label, "INVALID_RATE", "Rate must be greater than 0")
          return
        end

        @total_rows += 1
        return unless @sample_rows.size < MAX_PREVIEW_ROWS

        @sample_rows << {
          operational_date: operational_date.iso8601,
          base_currency: base_currency,
          quote_currency: quote_currency,
          rate: rate.to_s("F")
        }
      end

      def parse_date(value)
        return value.to_date if value.respond_to?(:to_date)
        return nil if value.nil?

        return Date.new(1899, 12, 30) + value.to_i if value.is_a?(Numeric)

        string_value = value.to_s.strip
        return nil if string_value.empty?

        Date.iso8601(string_value)
      rescue ArgumentError
        begin
          Date.parse(string_value)
        rescue ArgumentError
          nil
        end
      end

      def parse_rate(value)
        return nil if value.nil?

        string_value = value.to_s.strip
        return nil if string_value.empty?

        normalized = if string_value.include?(",") && string_value.include?(".")
          string_value.delete(",")
        elsif string_value.include?(",")
          string_value.tr(",", ".")
        else
          string_value
        end

        BigDecimal(normalized)
      rescue ArgumentError
        nil
      end

      def supported_pair?(base_currency, quote_currency)
        supported_pairs.include?([base_currency, quote_currency])
      end

      def supported_pairs
        @supported_pairs ||= Admin::Fx::RunRateGapProcessor::SUPPORTED_PAIRS.map { |pair| pair.map(&:upcase) }
      end

      def register_error(line, code, message)
        @errors << {line: line, code: code, message: message}
      end

      def result(valid)
        Result.new(valid?: valid, errors: @errors, sample_rows: @sample_rows, total_rows: @total_rows)
      end
    end
  end
end
