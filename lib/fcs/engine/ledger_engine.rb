# frozen_string_literal: true

module FCS
  module Engine
    class LedgerEngine
      def initialize(state: LedgerState.new, fee_enabled: true)
        @state = state
        @fee_enabled = fee_enabled
      end

      attr_reader :state

      def apply_trade!(trade)
        pos = @state.position_for(account_id: trade.fetch("accountId"), market_id: trade.fetch("marketId"))

        if @fee_enabled
          fee_quote = extract_fee_quote(trade)
          pos.apply_fee!(fee_quote) if fee_quote
        end

        case trade.fetch("side")
        when "BUY"
          apply_buy!(pos, trade)
        when "SELL"
          apply_sell!(pos, trade)
        else
          raise FCS::Error.new(
            FCS::Errors::ERR_VALIDATION,
            "Unsupported side",
            details: { side: trade["side"], tradeId: trade["tradeId"] }
          )
        end
      end

      private

      def apply_buy!(pos, t)
        qty = FCS::Types::Decimal18.from_string(t.fetch("quantityBase"))
        price = FCS::Types::Decimal18.from_string(t.fetch("priceQuotePerBase"))
        pos.apply_buy!(buy_qty: qty, buy_price: price)
      end

      def apply_sell!(pos, t)
        qty = FCS::Types::Decimal18.from_string(t.fetch("quantityBase"))
        price = FCS::Types::Decimal18.from_string(t.fetch("priceQuotePerBase"))
        pos.apply_sell!(sell_qty: qty, sell_price: price)
      end

      def extract_fee_quote(trade)
        fee = trade["fee"]
        return nil unless fee.is_a?(Hash) && fee.key?("amountQuote")

        FCS::Types::Decimal18.from_string(fee.fetch("amountQuote"))
      end
    end
  end
end
