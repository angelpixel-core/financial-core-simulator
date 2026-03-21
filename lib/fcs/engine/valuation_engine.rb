# frozen_string_literal: true

module FCS
  module Engine
    # Computes valuations from price snapshots.
    #
    # @example
    #   valuation = FCS::Engine::ValuationEngine.new(price_snapshot: snapshot)
    #   valuation.unrealized_pnl_quote(market_id: "btc-usd", position: position)
    class ValuationEngine
      # @param price_snapshot [Hash] snapshot payload with prices
      # @param dependencies [FCS::Engine::Dependencies]
      def initialize(price_snapshot:, dependencies: Dependencies.default)
        @dependencies = dependencies
        @prices = build_price_map(price_snapshot.fetch("prices"))
      end

      # Updates the current snapshot price for a market.
      #
      # @param market_id [String]
      # @param price_quote_per_base [String]
      # @return [void]
      def update_price!(market_id:, price_quote_per_base:)
        unless @prices.key?(market_id)
          raise @dependencies.error_class.new(
            @dependencies.errors_module::ERR_UNKNOWN_REFERENCE,
            "Unknown marketId",
            details: {marketId: market_id}
          )
        end

        @prices[market_id] = parse_price_decimal!(
          price_quote_per_base,
          field: "priceQuotePerBase",
          market_id: market_id
        )
      end

      # Computes unrealized PnL in quote currency for a position.
      #
      # @param market_id [String]
      # @param position [FCS::Engine::Position, FCS::Engine::PositionFifo]
      # @return [FCS::Types::Decimal18]
      def unrealized_pnl_quote(market_id:, position:)
        price = @prices.fetch(market_id) # validator ya garantizó que existe
        (price - position.avg_cost) * position.qty
      end

      # Returns the snapshot price for the market.
      #
      # @param market_id [String]
      # @return [FCS::Types::Decimal18]
      def snapshot_price_for(market_id)
        @prices.fetch(market_id)
      end

      private

      def build_price_map(prices_arr)
        prices_arr.each_with_object({}) do |p, acc|
          mid = p.fetch("marketId")
          acc[mid] = parse_price_decimal!(
            p.fetch("priceQuotePerBase"),
            field: "priceQuotePerBase",
            market_id: mid
          )
        end
      end

      def parse_price_decimal!(raw_price, field:, market_id:)
        if raw_price.is_a?(Float)
          raise @dependencies.error_class.new(
            @dependencies.errors_module::ERR_INVALID_NUMBER,
            "Float not allowed",
            details: {field: field, marketId: market_id}
          )
        end

        unless raw_price.is_a?(String) && raw_price.match?(/\A\d+(\.\d+)?\z/)
          raise @dependencies.error_class.new(
            @dependencies.errors_module::ERR_INVALID_NUMBER,
            "Invalid decimal string",
            details: {field: field, marketId: market_id, value: raw_price}
          )
        end

        if raw_price == "0"
          raise @dependencies.error_class.new(
            @dependencies.errors_module::ERR_INVALID_NUMBER,
            "Must be > 0",
            details: {field: field, marketId: market_id, value: raw_price}
          )
        end

        @dependencies.decimal_class.from_string(raw_price)
      end
    end
  end
end
