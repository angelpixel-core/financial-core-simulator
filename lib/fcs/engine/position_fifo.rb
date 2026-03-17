# frozen_string_literal: true

module FCS
  module Engine
    # FIFO position accounting helpers.
    class PositionFifo
      attr_reader :qty, :avg_cost, :realized_pnl_quote, :fees_quote

      def initialize(qty:, avg_cost:, realized_pnl_quote:, fees_quote:, lots:, dependencies: Dependencies.default)
        @qty = qty
        @avg_cost = avg_cost
        @realized_pnl_quote = realized_pnl_quote
        @fees_quote = fees_quote
        @lots = lots
        @dependencies = dependencies
      end

      def self.empty(dependencies: Dependencies.default)
        z = dependencies.decimal_class.new(0)
        new(qty: z, avg_cost: z, realized_pnl_quote: z, fees_quote: z, lots: [], dependencies: dependencies)
      end

      def apply_fee!(fee_quote)
        @fees_quote += fee_quote
        self
      end

      def realized_net_quote
        @realized_pnl_quote - @fees_quote
      end

      def apply_buy!(buy_qty:, buy_price:)
        @lots << { qty: buy_qty, price: buy_price }
        @qty += buy_qty
        recompute_avg_cost!
        self
      end

      def apply_sell!(sell_qty:, sell_price:)
        if (@qty - sell_qty).atoms.negative?
          raise @dependencies.error_class.new(
            @dependencies.errors_module::ERR_POSITION_NEGATIVE,
            "SELL would make position negative",
            details: { qty: @qty.to_s, sellQty: sell_qty.to_s }
          )
        end

        remaining = sell_qty
        while remaining.atoms.positive?
          current_lot = @lots.first
          lot_qty = current_lot.fetch(:qty)
          lot_price = current_lot.fetch(:price)
          consumed = if lot_qty.atoms <= remaining.atoms
                       @last_lot_fully_consumed = true
                       lot_qty
                     else
                       @last_lot_fully_consumed = false
                       remaining
                     end

          delta = (sell_price - lot_price) * consumed
          @realized_pnl_quote += delta

          if consumed.atoms == lot_qty.atoms
            @lots.shift
          else
            current_lot[:qty] = lot_qty - consumed
          end

          remaining -= consumed
        end

        @qty -= sell_qty
        recompute_avg_cost!
        self
      end

      private

      def recompute_avg_cost!
        if @qty.zero?
          @avg_cost = @dependencies.decimal_class.new(0)
          return
        end

        total_cost = @lots.reduce(@dependencies.decimal_class.new(0)) do |sum, lot|
          sum + (lot.fetch(:qty) * lot.fetch(:price))
        end

        @avg_cost = total_cost / @qty
      end
    end
  end
end
