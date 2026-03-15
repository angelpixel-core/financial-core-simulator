# frozen_string_literal: true

module FCS
  module Engine
    class ValuationEngine
      def initialize(price_snapshot:)
        @prices = build_price_map(price_snapshot.fetch("prices"))
      end

      def update_price!(market_id:, price_quote_per_base:)
        unless @prices.key?(market_id)
          raise FCS::Error.new(
            FCS::Errors::ERR_UNKNOWN_REFERENCE,
            "Unknown marketId",
            details: { marketId: market_id }
          )
        end

        @prices[market_id] = parse_price_decimal!(
          price_quote_per_base,
          field: "priceQuotePerBase",
          market_id: market_id
        )
      end

      def unrealized_pnl_quote(market_id:, position:)
        price = @prices.fetch(market_id) # validator ya garantizó que existe
        (price - position.avg_cost) * position.qty
      end

      def snapshot_price_for(market_id)
        @prices.fetch(market_id)
      end

      private

      def build_price_map(prices_arr)
        prices_arr.each_with_object({}) do |p, acc|
          mid = p.fetch("marketId")
          acc[mid] = FCS::Types::Decimal18.from_string(p.fetch("priceQuotePerBase"))
        end
      end

      def parse_price_decimal!(raw_price, field:, market_id:)
        if raw_price.is_a?(Float)
          raise FCS::Error.new(
            FCS::Errors::ERR_INVALID_NUMBER,
            "Float not allowed",
            details: { field: field, marketId: market_id }
          )
        end

        unless raw_price.is_a?(String) && raw_price.match?(/\A\d+(\.\d+)?\z/)
          raise FCS::Error.new(
            FCS::Errors::ERR_INVALID_NUMBER,
            "Invalid decimal string",
            details: { field: field, marketId: market_id, value: raw_price }
          )
        end

        if raw_price == "0"
          raise FCS::Error.new(
            FCS::Errors::ERR_INVALID_NUMBER,
            "Must be > 0",
            details: { field: field, marketId: market_id, value: raw_price }
          )
        end

        FCS::Types::Decimal18.from_string(raw_price)
      end
    end
  end
end
