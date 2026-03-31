# frozen_string_literal: true

require 'roo'

module Admin
  module Fx
    class RateUploadImporter
      Result = Struct.new(:valid?, :errors, keyword_init: true)

      REQUIRED_HEADERS = %w[operational_date rate].freeze

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
        workbook = Roo::Spreadsheet.open(@file_path)
        sheet_names = workbook.sheets
        if sheet_names.empty?
          register_error(1, 'EMPTY_FILE', 'No worksheets found')
          return result(false)
        end

        validate_sheet_names!(sheet_names)
        return result(false) if @errors.any?

        sheet_names.each do |sheet_name|
          base_currency, quote_currency = pair_from_sheet_name(sheet_name)
          next if base_currency.nil? || quote_currency.nil?

          sheet = workbook.sheet(sheet_name)
          headers = sheet.row(1).map { |value| value.to_s.strip }
          validate_headers!(headers, sheet_name)
          next if @errors.any?

          next if sheet.last_row.nil? || sheet.last_row < 2

          (2..sheet.last_row).each do |line|
            row = Hash[[headers, sheet.row(line)].transpose]
            next if row.values.all?(&:blank?)

            parse_row(row, line, base_currency: base_currency, quote_currency: quote_currency, sheet_name: sheet_name)
          end
        end

        if @rows.empty? && @errors.empty?
          register_error(1, 'EMPTY_FILE', 'No data rows found')
          return result(false)
        end

        return result(false) if @errors.any?

        @rows.each do |row|
          Admin::Fx::RateUpserter.call(
            operational_date: row[:operational_date],
            base_currency: row[:base_currency],
            quote_currency: row[:quote_currency],
            rate: row[:rate],
            source: 'upload',
            source_upload_id: @source_upload_id,
            enforce_operational_date: false,
            created_by_id: @created_by_id,
            created_by_role: @created_by_role,
            created_context: @created_context
          )
        end

        result(true)
      rescue StandardError => e
        register_error(1, 'IMPORT_FAILED', e.message)
        result(false)
      end

      private

      def validate_headers!(headers, sheet_name)
        missing = REQUIRED_HEADERS - headers
        return if missing.empty?

        register_error(1, 'INVALID_HEADERS', "Sheet #{sheet_name} missing columns: #{missing.join(', ')}")
      end

      def parse_row(row, line, base_currency:, quote_currency:, sheet_name:)
        operational_date = parse_date(row['operational_date'])
        rate = parse_rate(row['rate'])
        line_label = "#{sheet_name}:#{line}"

        if operational_date.nil?
          register_error(line_label, 'INVALID_DATE', 'Invalid operational date')
          return
        end

        if rate.nil?
          register_error(line_label, 'MISSING_FIELDS', 'Missing required values')
          return
        end

        if rate <= 0
          register_error(line_label, 'INVALID_RATE', 'Rate must be greater than 0')
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

        string_value = value.to_s.strip
        return nil if string_value.empty?

        Date.iso8601(string_value)
      rescue ArgumentError
        nil
      end

      def parse_rate(value)
        return nil if value.nil?

        string_value = value.to_s.strip
        return nil if string_value.empty?

        BigDecimal(string_value)
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

      def validate_sheet_names!(sheet_names)
        invalid_sheets = sheet_names.reject do |sheet_name|
          base_currency, quote_currency = pair_from_sheet_name(sheet_name)
          next true if base_currency.nil? || quote_currency.nil?

          valid_codes = base_currency.match?(FxDailyRate::CURRENCY_CODE_FORMAT) &&
                        quote_currency.match?(FxDailyRate::CURRENCY_CODE_FORMAT)
          valid_codes && supported_pair?(base_currency, quote_currency)
        end

        return if invalid_sheets.empty?

        register_error(1, 'UNSUPPORTED_PAIR', "Unsupported FX pair sheets: #{invalid_sheets.join(', ')}")
      end

      def pair_from_sheet_name(sheet_name)
        tokens = sheet_name.to_s.strip.upcase.split(/[^A-Z0-9]+/)
        return [nil, nil] unless tokens.size == 2

        [tokens[0], tokens[1]]
      end

      def register_error(line, code, message)
        @errors << { line: line, code: code, message: message }
      end

      def result(valid)
        Result.new(valid?: valid, errors: @errors)
      end
    end
  end
end
