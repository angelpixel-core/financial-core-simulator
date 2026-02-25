# frozen_string_literal: true

module FCS
  module Engine
    class ValuationEngine
      def initialize(price_snapshot:)
        @prices = build_price_map(price_snapshot.fetch("prices"))
      end

      def unrealized_pnl_quote(market_id:, position:)
        price = @prices.fetch(market_id) # validator ya garantizó que existe
        (price - position.avg_cost) * position.qty
      end

      private

      def build_price_map(prices_arr)
        prices_arr.each_with_object({}) do |p, acc|
          mid = p.fetch("marketId")
          acc[mid] = FCS::Types::Decimal18.from_string(p.fetch("priceQuotePerBase"))
        end
      end
    end
  end
end
