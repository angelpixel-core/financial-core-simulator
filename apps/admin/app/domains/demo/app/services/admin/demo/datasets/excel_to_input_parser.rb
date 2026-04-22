# frozen_string_literal: true

require "roo"
require "time"

module Admin
  module Demo
    module Datasets
      class ExcelToInputParser
        Result = Struct.new(:valid?, :input, :errors, keyword_init: true)

        MAX_FILE_SIZE_BYTES = Admin::UploadLimits.max_upload_file_size_bytes
        MAX_ROWS = Admin::UploadLimits.max_upload_rows
        MAX_PREVIEW_ROWS = Admin::UploadLimits.max_preview_rows
        MAX_PREVIEW_ERRORS = Admin::UploadLimits.max_preview_errors

        REQUIRED_HEADERS = %w[
          trade_id account_id market_id timestamp seq side
          quantity_base price_quote_per_base
        ].freeze
        ALLOWED_SIDES = %w[BUY SELL].freeze
        ALLOWED_MARKETS = %w[ETH-USD].freeze

        def self.call(file_path:, timeline_enabled: false, stage: :process)
          new(file_path: file_path, timeline_enabled: timeline_enabled, stage: stage).call
        end

        def initialize(file_path:, timeline_enabled: false, stage: :process)
          @file_path = file_path
          @timeline_enabled = timeline_enabled
          @stage = stage
          @errors = []
          @rows = []
          @row_errors = {}
        end

        def call
          if file_size_exceeded?
            register_file_size_error
            return build_result
          end

          sheet = Roo::Spreadsheet.open(@file_path).sheet(0)
          headers = []
          header_index = {}
          processed_rows = 0

          each_sheet_row(sheet) do |line, row_values|
            if line == 1
              headers = row_values.map { |value| value.to_s.strip }
              header_index = headers.each_with_index.each_with_object({}) do |(header, index), memo|
                next if header.empty?

                memo[header] = index
              end
              validate_headers!(headers)
              next
            end

            break if @errors.any? { |error| (error[:code] || error["code"]) == "INVALID_HEADERS" }

            processed_rows += 1
            if processed_rows > MAX_ROWS
              register_rows_limit_error(line)
              break
            end

            row = {}
            REQUIRED_HEADERS.each do |header|
              index = header_index[header]
              row[header] = index.nil? ? nil : row_values[index]
            end
            parse_row(row, line)
          end

          return build_result if @errors.any? { |error| (error[:code] || error["code"]) == "INVALID_HEADERS" }

          validate_sequences!
          validate_duplicates!

          build_result
        rescue => e
          log_limit_rejection(code: "PARSE_ERROR")
          @errors << {code: "PARSE_ERROR", message: e.message}
          build_result
        end

        private

        def build_result
          Result.new(
            valid?: @errors.empty?,
            input: build_input,
            errors: @errors
          )
        end

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

        def file_size_exceeded?
          Admin::UploadLimits.exceeds_file_size?(file_path: @file_path)
        end

        def register_file_size_error
          file_size = Admin::UploadLimits.file_size_bytes(file_path: @file_path)
          log_limit_rejection(code: "FILE_SIZE_EXCEEDED", file_size_bytes: file_size)
          @errors << {
            code: "FILE_SIZE_EXCEEDED",
            message: "File exceeds maximum size of #{MAX_FILE_SIZE_BYTES} bytes",
            file_size_bytes: file_size,
            max_file_size_bytes: MAX_FILE_SIZE_BYTES
          }
        rescue Errno::ENOENT
          @errors << {
            code: "FILE_NOT_FOUND",
            message: "File was not found for parsing"
          }
        end

        def register_rows_limit_error(line)
          log_limit_rejection(code: "MAX_ROWS_EXCEEDED", line: line)
          @errors << {
            line: line,
            code: "MAX_ROWS_EXCEEDED",
            message: "Row limit exceeded (max #{MAX_ROWS})",
            max_rows: MAX_ROWS
          }
        end

        def log_limit_rejection(code:, line: nil, file_size_bytes: nil)
          reason = case code
          when "FILE_SIZE_EXCEEDED" then "file_size_exceeded"
          when "MAX_ROWS_EXCEEDED" then "max_rows_exceeded"
          else
            "parse_error"
          end

          Admin::UploadTelemetry.rejection(
            domain: "demo",
            stage: @stage,
            reason: reason,
            code: code,
            max_rows: MAX_ROWS,
            max_file_size_bytes: MAX_FILE_SIZE_BYTES,
            line: line,
            file_size_bytes: file_size_bytes
          )
        end

        def validate_headers!(headers)
          missing = REQUIRED_HEADERS - headers
          return if missing.empty?

          @errors << {
            line: 1,
            code: "INVALID_HEADERS",
            message: "Missing columns: #{missing.join(", ")}"
          }
        end

        def parse_row(row, line)
          trade = {
            tradeId: row["trade_id"]&.to_s,
            accountId: row["account_id"]&.to_s,
            marketId: row["market_id"]&.to_s,
            timestamp: normalize_timestamp(row["timestamp"]),
            seq: row["seq"]&.to_i,
            side: row["side"]&.to_s,
            quantityBase: row["quantity_base"]&.to_s,
            priceQuotePerBase: row["price_quote_per_base"]&.to_s,
            line: line
          }

          validate_row(trade)
          @rows << trade
        end

        def validate_row(trade)
          line = trade[:line]

          if trade.values_at(:tradeId, :accountId, :marketId, :timestamp, :side).any? { |value| value.blank? }
            register_error(line, "MISSING_FIELDS", trade)
            return
          end

          unless ALLOWED_SIDES.include?(trade[:side])
            register_error(line, "INVALID_SIDE", trade)
            return
          end

          unless ALLOWED_MARKETS.include?(trade[:marketId])
            register_error(line, "UNKNOWN_MARKET", trade)
            return
          end

          if trade[:priceQuotePerBase].to_f <= 0
            register_error(line, "INVALID_PRICE", trade)
            return
          end

          return unless trade[:quantityBase].to_f <= 0

          register_error(line, "INVALID_QUANTITY", trade)
          nil
        end

        def validate_sequences!
          grouped = valid_rows.group_by { |row| [row[:accountId], row[:marketId]] }

          grouped.each_value do |rows|
            rows.each_cons(2) do |prev, current|
              if current[:seq] <= prev[:seq]
                register_error(current[:line], "SEQ_OUT_OF_ORDER", current)
                next
              end

              if current[:timestamp] < prev[:timestamp]
                register_error(current[:line], "TIMESTAMP_INCONSISTENT",
                  current)
              end
            end
          end
        end

        def validate_duplicates!
          duplicates = valid_rows.group_by { |row| row[:tradeId] }.select { |_id, rows| rows.size > 1 }
          duplicates.each_value do |rows|
            rows.drop(1).each do |row|
              register_error(row[:line], "DUPLICATE_TRADE_ID", row)
            end
          end
        end

        def register_error(line, code, trade = nil)
          return if @row_errors.key?(line)

          @row_errors[line] = code
          @errors << {
            line: line,
            code: code,
            source: "dataset_upload",
            row_index: line.to_i - 2,
            trade_id: trade&.dig(:tradeId),
            account_id: trade&.dig(:accountId),
            market_id: trade&.dig(:marketId)
          }
        end

        def build_input
          trades = valid_rows.map { |row| row.except(:line) }
          input = {
            schemaVersion: "1.0",
            accounts: unique(:accountId).map { |id| {accountId: id} },
            markets: unique(:marketId).map { |id| {marketId: id} },
            trades: trades,
            priceSnapshot: default_price_snapshot,
            feeModel: {enabled: false}
          }

          input[:timeline] = {events: build_timeline_events} if @timeline_enabled

          input
        end

        def build_timeline_events
          sorted = valid_rows.sort_by { |row| [row[:timestamp] || 0, row[:seq] || 0, row[:line] || 0] }

          sorted.map.with_index(1) do |row, index|
            trade = row.except(:line)
            {
              eventType: "TRADE_APPLIED",
              timelineSeq: index,
              timestamp: timeline_iso_timestamp(trade[:timestamp]),
              source: "admin.demo_dataset",
              externalId: trade[:tradeId],
              trade: trade
            }
          end
        end

        def unique(key)
          valid_rows.map { |row| row[key] }.uniq
        end

        def default_price_snapshot
          {
            valuationTimestamp: Time.now.utc.iso8601,
            prices: unique(:marketId).map do |market|
              {marketId: market, priceQuotePerBase: "100"}
            end,
            fx: {quoteUsd: "1"}
          }
        end

        def valid_rows
          @rows.reject { |row| @row_errors.key?(row[:line]) }
        end

        def normalize_timestamp(value)
          return nil if value.nil?
          return nil if value.respond_to?(:value) && value.value.nil?
          return nil if value.respond_to?(:empty?) && value.empty?

          if value.is_a?(Time) || value.is_a?(Date) || value.is_a?(DateTime) || value.is_a?(ActiveSupport::TimeWithZone)
            return value.to_time.to_i
          end

          return value.to_i if value.is_a?(Numeric)

          string_value = value.to_s.strip
          return nil if string_value.empty?

          return Integer(string_value) if string_value.match?(/\A-?\d+\z/)

          Time.iso8601(string_value).to_i
        rescue ArgumentError
          begin
            Time.parse(string_value).to_i
          rescue ArgumentError, TypeError
            nil
          end
        rescue TypeError
          nil
        end

        def timeline_iso_timestamp(timestamp)
          return nil unless timestamp.is_a?(Integer)

          Time.at(timestamp).utc.strftime("%Y-%m-%dT%H:%M:%SZ")
        end
      end
    end
  end
end
