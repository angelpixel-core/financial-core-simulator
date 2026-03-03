module FCS
  module Application
    class EventTimelineProcessor
      def call(events:, ledger:, valuation:)
        events
          .sort_by { |event| event.fetch('timelineSeq') }
          .each do |event|
            case event.fetch('eventType')
            when 'PRICE_UPDATED'
              valuation.update_price!(
                market_id: event.fetch('marketId'),
                price_quote_per_base: event.fetch('priceQuotePerBase')
              )
            when 'TRADE_APPLIED'
              ledger.apply_trade!(event.fetch('trade'))
            end
          end
      end
    end
  end
end
