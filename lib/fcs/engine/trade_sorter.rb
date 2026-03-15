# frozen_string_literal: true

module FCS
  module Engine
    # Sorts trades deterministically for stable execution.
    class TradeSorter
      def sort(trades)
        trades.sort_by { |trade| sort_key_for(trade) }
      end

      private

      def sort_key_for(trade)
        [
          trade.fetch("timestamp"),
          trade.fetch("seq"),
          trade["accountId"].to_s,
          trade["marketId"].to_s,
          trade["tradeId"].to_s
        ]
      end
    end
  end
end
