# frozen_string_literal: true

module FCS
  module Engine
    class LedgerEngine
      def initialize(state: LedgerState.new)
        @state = state
      end

      attr_reader :state

      def apply_trade!(trade)
        case trade.fetch("side")
        when "BUY"
          apply_buy!(trade)
        when "SELL"
          apply_sell!(trade)
        else
          raise FCS::Error.new(
            FCS::Errors::ERR_VALIDATION,
            "Unsupported side",
            details: { side: trade["side"], tradeId: trade["tradeId"] }
          )
        end
      end

      private

      def apply_buy!(t)
        pos = @state.position_for(account_id: t.fetch("accountId"), market_id: t.fetch("marketId"))
        qty = FCS::Types::Decimal18.from_string(t.fetch("quantityBase"))
        price = FCS::Types::Decimal18.from_string(t.fetch("priceQuotePerBase"))
        pos.apply_buy!(buy_qty: qty, buy_price: price)
      end

      def apply_sell!(t)
        pos = @state.position_for(account_id: t.fetch("accountId"), market_id: t.fetch("marketId"))
        qty = FCS::Types::Decimal18.from_string(t.fetch("quantityBase"))
        price = FCS::Types::Decimal18.from_string(t.fetch("priceQuotePerBase"))
        pos.apply_sell!(sell_qty: qty, sell_price: price)
      end
    end
  end
end
