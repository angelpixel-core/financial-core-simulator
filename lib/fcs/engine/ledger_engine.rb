# frozen_string_literal: true

module FCS
  module Engine
    class LedgerEngine
      ACCOUNTING_METHOD_AVERAGE = 'AVERAGE_COST'
      ACCOUNTING_METHOD_FIFO = 'FIFO'

      def initialize(
        state: nil,
        fee_enabled: true,
        accounting_method: ACCOUNTING_METHOD_AVERAGE,
        account_collateral: {},
        max_leverage: nil,
        risk_engine: nil
      )
        @state = state || LedgerState.new(position_builder: position_builder_for(accounting_method))
        @fee_enabled = fee_enabled
        @accounting_method = accounting_method
        @risk_engine = risk_engine || FCS::Engine::RiskEngine.new(
          account_collateral: account_collateral,
          risk_config: { maxLeverage: max_leverage }
        )
      end

      attr_reader :state

      def apply_trade!(trade)
        pos = @state.position_for(account_id: trade.fetch('accountId'), market_id: trade.fetch('marketId'))
        @risk_engine.pre_trade_check!(
          account_id: trade.fetch('accountId'),
          market_id: trade.fetch('marketId'),
          side: trade.fetch('side'),
          quantity: trade.fetch('quantityBase'),
          price: trade.fetch('priceQuotePerBase'),
          position: pos,
          accounting_method: @accounting_method
        )

        if @fee_enabled
          fee_quote = extract_fee_quote(trade)
          pos.apply_fee!(fee_quote) if fee_quote
        end

        case trade.fetch('side')
        when 'BUY'
          apply_buy!(pos, trade)
        when 'SELL'
          apply_sell!(pos, trade)
        else
          raise FCS::Error.new(
            FCS::Errors::ERR_VALIDATION,
            'Unsupported side',
            details: { side: trade['side'], tradeId: trade['tradeId'] }
          )
        end
      end

      private

      def position_builder_for(accounting_method)
        case accounting_method
        when ACCOUNTING_METHOD_AVERAGE
          -> { Position.empty }
        when ACCOUNTING_METHOD_FIFO
          -> { PositionFifo.empty }
        else
          raise FCS::Error.new(
            FCS::Errors::ERR_VALIDATION,
            'Unsupported accounting method',
            details: { accountingMethod: accounting_method }
          )
        end
      end

      def apply_buy!(pos, t)
        qty = FCS::Types::Decimal18.from_string(t.fetch('quantityBase'))
        price = FCS::Types::Decimal18.from_string(t.fetch('priceQuotePerBase'))
        pos.apply_buy!(buy_qty: qty, buy_price: price)
      end

      def apply_sell!(pos, t)
        qty = FCS::Types::Decimal18.from_string(t.fetch('quantityBase'))
        price = FCS::Types::Decimal18.from_string(t.fetch('priceQuotePerBase'))
        pos.apply_sell!(sell_qty: qty, sell_price: price)
      end

      def extract_fee_quote(trade)
        fee = trade['fee']
        return nil unless fee.is_a?(Hash) && fee.key?('amountQuote')

        FCS::Types::Decimal18.from_string(fee.fetch('amountQuote'))
      end
    end
  end
end
