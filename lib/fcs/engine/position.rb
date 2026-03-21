# frozen_string_literal: true

module FCS
  module Engine
    # Represents a single account-market position.
    #
    # @example
    #   position = FCS::Engine::Position.empty
    #   position.apply_buy!(buy_qty: qty, buy_price: price)
    class Position
      attr_reader :qty, :avg_cost, :realized_pnl_quote, :fees_quote

      # @param qty [FCS::Types::Decimal18]
      # @param avg_cost [FCS::Types::Decimal18]
      # @param realized_pnl_quote [FCS::Types::Decimal18]
      # @param fees_quote [FCS::Types::Decimal18]
      # @param dependencies [FCS::Engine::Dependencies]
      def initialize(qty:, avg_cost:, realized_pnl_quote:, fees_quote:, dependencies: Dependencies.default)
        @qty = qty
        @avg_cost = avg_cost
        @realized_pnl_quote = realized_pnl_quote
        @fees_quote = fees_quote
        @dependencies = dependencies
      end

      # Returns an empty long-only position.
      #
      # @param dependencies [FCS::Engine::Dependencies]
      # @return [FCS::Engine::Position]
      def self.empty(dependencies: Dependencies.default)
        z = dependencies.decimal_class.new(0)
        new(qty: z, avg_cost: z, realized_pnl_quote: z, fees_quote: z, dependencies: dependencies)
      end

      # Applies a fee in quote currency.
      #
      # @param fee_quote [FCS::Types::Decimal18]
      # @return [FCS::Engine::Position]
      def apply_fee!(fee_quote)
        @fees_quote += fee_quote
        self
      end

      # Returns realized PnL net of fees.
      #
      # @return [FCS::Types::Decimal18]
      def realized_net_quote
        @realized_pnl_quote - @fees_quote
      end

      # Applies a buy trade and updates average cost.
      #
      # @param buy_qty [FCS::Types::Decimal18]
      # @param buy_price [FCS::Types::Decimal18]
      # @return [FCS::Engine::Position]
      def apply_buy!(buy_qty:, buy_price:)
        raise_invalid_buy_quantity!(buy_qty) if buy_qty.atoms <= 0
        raise_long_only_violation! if @qty.atoms.negative?

        total_cost = (@qty * @avg_cost) + (buy_qty * buy_price)
        new_qty = @qty + buy_qty
        new_avg = total_cost / new_qty

        @qty = new_qty
        @avg_cost = new_avg
        self
      end

      # Applies a sell trade and updates realized PnL.
      #
      # @param sell_qty [FCS::Types::Decimal18]
      # @param sell_price [FCS::Types::Decimal18]
      # @return [FCS::Engine::Position]
      def apply_sell!(sell_qty:, sell_price:)
        raise_long_only_violation! if (@qty - sell_qty).atoms.negative?

        delta = (sell_price - @avg_cost) * sell_qty
        @realized_pnl_quote += delta

        @qty -= sell_qty
        @avg_cost = @dependencies.decimal_class.new(0) if @qty.zero?

        self
      end

      private

      def raise_invalid_buy_quantity!(buy_qty)
        raise @dependencies.error_class.new(
          @dependencies.errors_module::ERR_VALIDATION,
          "BUY quantity must be > 0",
          details: {quantityBase: buy_qty.to_s}
        )
      end

      def raise_long_only_violation!
        raise @dependencies.error_class.new(
          @dependencies.errors_module::ERR_POSITION_NEGATIVE,
          "SELL would make position negative",
          details: {qty: @qty.to_s}
        )
      end

      attr_writer :qty, :avg_cost, :realized_pnl_quote, :fees_quote
    end
  end
end
