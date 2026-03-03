module FCS
  module Application
    class EventTimelineProcessor
      def call(events:, ledger:, valuation:, checkpoint: nil, checkpoint_store: nil, input_hash: nil)
        checkpoint_seq = restore_checkpoint_state!(checkpoint: checkpoint, ledger: ledger)
        processed_events = 0

        events
          .sort_by { |event| event.fetch('timelineSeq') }
          .each do |event|
            timeline_seq = event.fetch('timelineSeq')
            next if checkpoint_seq && timeline_seq <= checkpoint_seq

            case event.fetch('eventType')
            when 'PRICE_UPDATED'
              valuation.update_price!(
                market_id: event.fetch('marketId'),
                price_quote_per_base: event.fetch('priceQuotePerBase')
              )
            when 'TRADE_APPLIED'
              ledger.apply_trade!(event.fetch('trade'))
            end

            processed_events += 1
            checkpoint_store&.write_if_due!(
              event_count: processed_events,
              timeline_seq: timeline_seq,
              state: capture_state(ledger),
              input_hash: input_hash || ''
            )
          end
      end

      private

      def restore_checkpoint_state!(checkpoint:, ledger:)
        return nil unless checkpoint.is_a?(Hash)

        accounts = checkpoint.dig('state', 'accounts')
        return nil unless accounts.is_a?(Array)

        accounts.each do |account|
          account_id = account.fetch('accountId')
          markets = account.fetch('markets', [])

          markets.each do |market|
            restore_market_position!(
              ledger: ledger,
              account_id: account_id,
              market_id: market.fetch('marketId'),
              quantity: market.fetch('quantity', '0'),
              avg_cost: market.fetch('avgCost', '0')
            )
          end
        end

        checkpoint['timelineSeq']
      end

      def restore_market_position!(ledger:, account_id:, market_id:, quantity:, avg_cost:)
        qty = FCS::Types::Decimal18.from_string(quantity)
        return if qty.zero?

        price = FCS::Types::Decimal18.from_string(avg_cost)
        position = ledger.state.position_for(account_id: account_id, market_id: market_id)

        if qty.atoms.positive?
          position.apply_buy!(buy_qty: qty, buy_price: price)
        else
          position.apply_sell!(sell_qty: qty.abs, sell_price: price)
        end
      end

      def capture_state(ledger)
        grouped = ledger.state.positions.each_with_object(Hash.new { |h, k| h[k] = [] }) do |(key, position), acc|
          account_id, market_id = key.split('|', 2)
          acc[account_id] << {
            'marketId' => market_id,
            'quantity' => position.qty.to_s,
            'avgCost' => position.avg_cost.to_s
          }
        end

        {
          'accounts' => grouped.sort_by { |account_id, _| account_id }.map do |account_id, markets|
            {
              'accountId' => account_id,
              'markets' => markets.sort_by { |market| market.fetch('marketId') }
            }
          end
        }
      end
    end
  end
end
