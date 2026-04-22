# frozen_string_literal: true

require "roo"

module Admin
  module Fx
    class RateUploadImporter
      Result = Struct.new(:valid?, :errors, :message, keyword_init: true)

      REQUIRED_HEADERS = %w[id operational_date base_currency quote_currency rate].freeze
      MAX_FILE_SIZE_BYTES = Admin::UploadLimits.max_upload_file_size_bytes
      MAX_ROWS = Admin::UploadLimits.max_upload_rows
      BATCH_SIZE = Admin::UploadLimits.batch_size

      def self.call(file_path:, created_by_id: nil, created_by_role: nil, created_context: {}, source_upload_id: nil)
        new(
          file_path: file_path,
          created_by_id: created_by_id,
          created_by_role: created_by_role,
          created_context: created_context,
          source_upload_id: source_upload_id
        ).call
      end

      def initialize(file_path:, created_by_id:, created_by_role:, created_context: {}, source_upload_id: nil)
        @file_path = file_path
        @created_by_id = created_by_id
        @created_by_role = created_by_role
        @created_context = created_context
        @source_upload_id = source_upload_id
        @errors = []
        @rows = []
      end

      def call
        if Admin::UploadLimits.exceeds_file_size?(file_path: @file_path)
          register_error(1, "FILE_SIZE_EXCEEDED", "File exceeds maximum size of #{MAX_FILE_SIZE_BYTES} bytes")
          Admin::UploadTelemetry.rejection(
            domain: "fx",
            stage: "process",
            reason: "file_size_exceeded",
            file_size_bytes: Admin::UploadLimits.file_size_bytes(file_path: @file_path),
            max_file_size_bytes: MAX_FILE_SIZE_BYTES
          )
          return result(false)
        end

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

        return result(true, message: "No FX rates found. Upload skipped.") if sheet.last_row.nil? || sheet.last_row < 2

        processed_rows = 0
        each_sheet_row(sheet) do |line, row_values|
          next if line == 1

          row = headers.zip(row_values).to_h
          next if row.values.all?(&:blank?)

          processed_rows += 1
          if processed_rows > MAX_ROWS
            register_error(line, "MAX_ROWS_EXCEEDED", "Row limit exceeded (max #{MAX_ROWS})")
            Admin::UploadTelemetry.rejection(
              domain: "fx",
              stage: "process",
              reason: "max_rows_exceeded",
              line: line,
              max_rows: MAX_ROWS
            )
            break
          end

          parse_row(row, line, sheet_name: sheet_name)
        end

        return result(true, message: "No FX rates found. Upload skipped.") if @rows.empty? && @errors.empty?

        return result(false) if @errors.any?

        @rows.each_slice(BATCH_SIZE) do |batch|
          batch.each do |row|
            Admin::Fx::RateUpserter.call(
              operational_date: row[:operational_date],
              base_currency: row[:base_currency],
              quote_currency: row[:quote_currency],
              rate: row[:rate],
              source: "upload",
              source_upload_id: @source_upload_id,
              enforce_operational_date: false,
              created_by_id: @created_by_id,
              created_by_role: @created_by_role,
              created_context: @created_context
            )
          end
        end

        result(true)
      rescue => e
        Admin::UploadTelemetry.rejection(
          domain: "fx",
          stage: "process",
          reason: "parse_error",
          message: e.message
        )
        register_error(1, "IMPORT_FAILED", e.message)
        result(false)
      end

      private

      def each_sheet_row(sheet)
        if sheet.respond_to?(:each_row_streaming)
          sheet.each_row_streaming(pad_cells: true).with_index(1) do |cells, line|
            values = cells.map { |cell| cell.respond_to?(:value) ? cell.value : cell }
            yield line, values
          end
          return
        end

        (1..sheet.last_row).each do |line|
          yield line, sheet.row(line)
        end
      end

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

        operational_date = parse_date(row["operational_date"])
        rate = parse_rate(row["rate"])
        base_currency = row["base_currency"].to_s.strip.upcase
        quote_currency = row["quote_currency"].to_s.strip.upcase
        line_label = "#{sheet_name}:#{line}"

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

        @rows << {
          operational_date: operational_date,
          base_currency: base_currency,
          quote_currency: quote_currency,
          rate: rate
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
        @supported_pairs ||= Admin::Fx::RunRateGapProcessor::SUPPORTED_PAIRS
          .map { |pair| pair.map(&:upcase) }
      end

      def register_error(line, code, message)
        @errors << {line: line, code: code, message: message}
      end

      def result(valid, message: nil)
        Result.new(valid?: valid, errors: @errors, message: message)
      end
    end
  end
end
