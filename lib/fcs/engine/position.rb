# frozen_string_literal: true

module FCS
  module Engine
    class Position
      attr_reader :qty, :avg_cost

      def initialize(qty:, avg_cost:)
        @qty = qty
        @avg_cost = avg_cost
      end

      def self.empty
        new(qty: FCS::Types::Decimal18.new(0), avg_cost: FCS::Types::Decimal18.new(0))
      end

      def apply_buy!(buy_qty:, buy_price:)
        # new_avg = (old_qty*old_avg + new_qty*price) / (old_qty + new_qty)
        total_cost = (@qty * @avg_cost) + (buy_qty * buy_price)
        new_qty = @qty + buy_qty
        new_avg = total_cost / new_qty

        @qty = new_qty
        @avg_cost = new_avg
        self
      end

      private

      attr_writer :qty, :avg_cost
    end
  end
end
