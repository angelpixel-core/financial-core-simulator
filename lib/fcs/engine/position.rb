# frozen_string_literal: true

module FCS
  module Engine
    class Position
      attr_reader :qty, :avg_cost, :realized_pnl_quote

      def initialize(qty:, avg_cost:, realized_pnl_quote:)
        @qty = qty
        @avg_cost = avg_cost
        @realized_pnl_quote = realized_pnl_quote
      end

      def self.empty
        z = FCS::Types::Decimal18.new(0)
        new(qty: z, avg_cost: z, realized_pnl_quote: z)
      end

      def apply_buy!(buy_qty:, buy_price:)
        total_cost = (@qty * @avg_cost) + (buy_qty * buy_price)
        new_qty = @qty + buy_qty
        new_avg = total_cost / new_qty

        @qty = new_qty
        @avg_cost = new_avg
        self
      end

      def apply_sell!(sell_qty:, sell_price:)
        if (@qty - sell_qty).atoms < 0
          raise FCS::Error.new(
            FCS::Errors::ERR_POSITION_NEGATIVE,
            "SELL would make position negative",
            details: {
              qty: @qty.to_s,
              sellQty: sell_qty.to_s
            }
          )
        end

        # realized += (sell_price - avg_cost) * sell_qty
        delta = (sell_price - @avg_cost) * sell_qty
        @realized_pnl_quote = @realized_pnl_quote + delta

        @qty = @qty - sell_qty

        # si queda en 0, avg_cost = 0 (PRD)
        if @qty.zero?
          @avg_cost = FCS::Types::Decimal18.new(0)
        end

        self
      end

      private

      attr_writer :qty, :avg_cost, :realized_pnl_quote
    end
  end
end
