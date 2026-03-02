# frozen_string_literal: true

module FCS
  module Engine
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
        if @qty.atoms >= 0
          total_cost = (@qty * @avg_cost) + (buy_qty * buy_price)
          new_qty = @qty + buy_qty
          new_avg = total_cost / new_qty

          @qty = new_qty
          @avg_cost = new_avg
          return self
        end

        short_qty = @qty.abs
        cover_qty = buy_qty.atoms <= short_qty.atoms ? buy_qty : short_qty

        delta = (@avg_cost - buy_price) * cover_qty
        @realized_pnl_quote += delta

        new_qty_atoms = @qty.atoms + buy_qty.atoms
        @qty = FCS::Types::Decimal18.new(new_qty_atoms)

        @avg_cost = if new_qty_atoms < 0
                      @avg_cost
                    elsif new_qty_atoms == 0
                      FCS::Types::Decimal18.new(0)
                    else
                      buy_price
                    end

        self
      end

      def apply_sell!(sell_qty:, sell_price:)
        if @qty.atoms <= 0
          total_short_cost = (@qty.abs * @avg_cost) + (sell_qty * sell_price)
          new_short_qty = @qty.abs + sell_qty

          @qty = FCS::Types::Decimal18.new(-new_short_qty.atoms)
          @avg_cost = total_short_cost / new_short_qty
          return self
        end

        close_qty = sell_qty.atoms <= @qty.atoms ? sell_qty : @qty
        delta = (sell_price - @avg_cost) * close_qty
        @realized_pnl_quote += delta

        remaining_sell_atoms = sell_qty.atoms - close_qty.atoms

        if remaining_sell_atoms > 0
          remaining_sell = FCS::Types::Decimal18.new(remaining_sell_atoms)
          @qty = FCS::Types::Decimal18.new(-remaining_sell.atoms)
          @avg_cost = sell_price
        else
          @qty -= sell_qty
          @avg_cost = FCS::Types::Decimal18.new(0) if @qty.zero?
        end

        self
      end

      private

      attr_writer :qty, :avg_cost, :realized_pnl_quote, :fees_quote
    end
  end
end
