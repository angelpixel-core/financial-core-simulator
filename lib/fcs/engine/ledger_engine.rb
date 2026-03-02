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
        max_leverage: nil
      )
        @state = state || LedgerState.new(position_builder: position_builder_for(accounting_method))
        @fee_enabled = fee_enabled
        @accounting_method = accounting_method
        @account_collateral = account_collateral
        @max_leverage = max_leverage
      end

      attr_reader :state

      def apply_trade!(trade)
        pos = @state.position_for(account_id: trade.fetch('accountId'), market_id: trade.fetch('marketId'))
        enforce_short_constraints!(pos, trade)

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

      def enforce_short_constraints!(pos, trade)
        projected_qty_atoms = projected_qty_atoms(pos: pos, trade: trade)
        return unless projected_qty_atoms < 0

        if @accounting_method == ACCOUNTING_METHOD_FIFO
          raise FCS::Error.new(
            FCS::Errors::ERR_VALIDATION,
            'Short selling is not supported with FIFO accounting',
            details: { accountingMethod: @accounting_method }
          )
        end

        account_id = trade.fetch('accountId')
        collateral = @account_collateral[account_id]

        if collateral.nil? || @max_leverage.nil? || collateral.zero?
          raise FCS::Error.new(
            FCS::Errors::ERR_VALIDATION,
            'Short selling requires collateralQuote and riskModel.maxLeverage',
            details: { accountId: account_id }
          )
        end

        projected_abs_qty = FCS::Types::Decimal18.new(projected_qty_atoms.abs)
        price = FCS::Types::Decimal18.from_string(trade.fetch('priceQuotePerBase'))
        projected_notional = projected_abs_qty * price
        max_notional = collateral * @max_leverage
        return if projected_notional.atoms <= max_notional.atoms

        raise FCS::Error.new(
          FCS::Errors::ERR_VALIDATION,
          'Leverage limit exceeded',
          details: {
            accountId: account_id,
            projectedNotionalQuote: projected_notional.to_s,
            collateralQuote: collateral.to_s,
            maxLeverage: @max_leverage.to_s
          }
        )
      end

      def projected_qty_atoms(pos:, trade:)
        qty = FCS::Types::Decimal18.from_string(trade.fetch('quantityBase'))

        case trade.fetch('side')
        when 'BUY'
          pos.qty.atoms + qty.atoms
        when 'SELL'
          pos.qty.atoms - qty.atoms
        else
          pos.qty.atoms
        end
      end

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
