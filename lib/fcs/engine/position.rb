# frozen_string_literal: true

module FCS
  module Engine
    # Represents a single account-market position.
    class Position
      attr_reader :qty, :avg_cost, :realized_pnl_quote, :fees_quote

      def initialize(qty:, avg_cost:, realized_pnl_quote:, fees_quote:)
        @qty = qty
        @avg_cost = avg_cost
        @realized_pnl_quote = realized_pnl_quote
        @fees_quote = fees_quote
      end

      def self.empty
        z = FCS::Types::Decimal18.new(0)
        new(qty: z, avg_cost: z, realized_pnl_quote: z, fees_quote: z)
      end

      def apply_fee!(fee_quote)
        @fees_quote += fee_quote
        self
      end

      def realized_net_quote
        @realized_pnl_quote - @fees_quote
      end

      def apply_buy!(buy_qty:, buy_price:)
        raise_invalid_buy_quantity!(buy_qty) if buy_qty.atoms <= 0
        raise_long_only_violation! if @qty.atoms < 0

        total_cost = (@qty * @avg_cost) + (buy_qty * buy_price)
        new_qty = @qty + buy_qty
        new_avg = total_cost / new_qty

        @qty = new_qty
        @avg_cost = new_avg
        self
      end

      def apply_sell!(sell_qty:, sell_price:)
        raise_long_only_violation! if (@qty - sell_qty).atoms < 0

        delta = (sell_price - @avg_cost) * sell_qty
        @realized_pnl_quote += delta

        @qty -= sell_qty
        @avg_cost = FCS::Types::Decimal18.new(0) if @qty.zero?

        self
      end

      private

      def raise_invalid_buy_quantity!(buy_qty)
        raise FCS::Error.new(
          FCS::Errors::ERR_VALIDATION,
          "BUY quantity must be > 0",
          details: { quantityBase: buy_qty.to_s }
        )
      end

      def raise_long_only_violation!
        raise FCS::Error.new(
          FCS::Errors::ERR_POSITION_NEGATIVE,
          "SELL would make position negative",
          details: { qty: @qty.to_s }
        )
      end

      attr_writer :qty, :avg_cost, :realized_pnl_quote, :fees_quote
    end
  end
end
