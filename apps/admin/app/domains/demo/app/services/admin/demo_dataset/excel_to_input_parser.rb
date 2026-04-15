# frozen_string_literal: true

require "roo"
require "time"

module Admin
  module DemoDataset
    class ExcelToInputParser
      Result = Struct.new(:valid?, :input, :errors, keyword_init: true)

      REQUIRED_HEADERS = %w[
        trade_id account_id market_id timestamp seq side
        quantity_base price_quote_per_base
      ].freeze
      ALLOWED_SIDES = %w[BUY SELL].freeze
      ALLOWED_MARKETS = %w[ETH-USD].freeze

      def self.call(file_path:, timeline_enabled: false)
        new(file_path: file_path, timeline_enabled: timeline_enabled).call
      end

      def initialize(file_path:, timeline_enabled: false)
        @file_path = file_path
        @timeline_enabled = timeline_enabled
        @errors = []
        @rows = []
        @row_errors = {}
        @row_ingestor = FCS::Application::IngestDemoTradeRow.new
      end

      def call
        sheet = Roo::Spreadsheet.open(@file_path).sheet(0)
        headers = sheet.row(1).map(&:to_s)

        validate_headers!(headers)

        (2..sheet.last_row).each do |i|
          row = headers.zip(sheet.row(i)).to_h
          parse_row(row, i)
        end

        validate_sequences!
        validate_duplicates!

        Result.new(
          valid?: @errors.empty?,
          input: build_input,
          errors: @errors
        )
      end

      private

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
        trade = @row_ingestor.call(row: row, line: line)
      rescue ArgumentError
        register_error(line, "MISSING_FIELDS")
        trade = build_fallback_trade(row, line)
      ensure
        validate_row(trade)
        @rows << trade
      end

      def validate_row(trade)
        line = trade[:line]

        if trade.values_at(:tradeId, :accountId, :marketId, :timestamp, :side).any? { |value| value.blank? }
          register_error(line, "MISSING_FIELDS")
          return
        end

        unless ALLOWED_SIDES.include?(trade[:side])
          register_error(line, "INVALID_SIDE")
          return
        end

        unless ALLOWED_MARKETS.include?(trade[:marketId])
          register_error(line, "UNKNOWN_MARKET")
          return
        end

        if trade[:priceQuotePerBase].to_f <= 0
          register_error(line, "INVALID_PRICE")
          return
        end

        return unless trade[:quantityBase].to_f <= 0

        register_error(line, "INVALID_QUANTITY")
        nil
      end

      def validate_sequences!
        grouped = valid_rows.group_by { |row| [row[:accountId], row[:marketId]] }

        grouped.each_value do |rows|
          rows.each_cons(2) do |prev, current|
            if current[:seq] <= prev[:seq]
              register_error(current[:line], "SEQ_OUT_OF_ORDER")
              next
            end

            register_error(current[:line], "TIMESTAMP_INCONSISTENT") if current[:timestamp] < prev[:timestamp]
          end
        end
      end

      def validate_duplicates!
        duplicates = valid_rows.group_by { |row| row[:tradeId] }.select { |_id, rows| rows.size > 1 }
        duplicates.each_value do |rows|
          rows.drop(1).each do |row|
            register_error(row[:line], "DUPLICATE_TRADE_ID")
          end
        end
      end

      def register_error(line, code)
        return if @row_errors.key?(line)

        @row_errors[line] = code
        @errors << {line: line, code: code}
      end

      def build_input
        trades = @rows.map { |row| row.except(:line) }
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
        sorted = @rows.sort_by { |row| [row[:timestamp] || 0, row[:seq] || 0, row[:line] || 0] }

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
        @rows.map { |row| row[key] }.uniq
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

      def timeline_iso_timestamp(timestamp)
        return nil unless timestamp.is_a?(Integer)

        Time.at(timestamp).utc.strftime("%Y-%m-%dT%H:%M:%SZ")
      end

      def build_fallback_trade(row, line)
        {
          tradeId: row["trade_id"]&.to_s,
          accountId: row["account_id"]&.to_s,
          marketId: row["market_id"]&.to_s,
          timestamp: nil,
          seq: row["seq"]&.to_i,
          side: row["side"]&.to_s,
          quantityBase: row["quantity_base"]&.to_s,
          priceQuotePerBase: row["price_quote_per_base"]&.to_s,
          line: line
        }
      end
    end
  end
end
