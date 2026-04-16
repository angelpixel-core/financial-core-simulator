# frozen_string_literal: true

require "time"

module FCS
  module Application
    class IngestDemoTradeRow
      def call(row:, line:)
        attributes = {
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

        FCS::Contracts::TradeInput.from_hash!(attributes)
      end

      private

      def normalize_timestamp(value)
        return nil if value.nil?
        return value.to_i if value.is_a?(Numeric)

        string_value = value.to_s.strip
        return nil if string_value.empty?

        Integer(string_value)
      rescue ArgumentError
        begin
          Time.parse(string_value).to_i
        rescue ArgumentError, TypeError
          nil
        end
      rescue TypeError
        nil
      end
    end
  end
end
