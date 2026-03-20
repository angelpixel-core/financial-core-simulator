# frozen_string_literal: true

module FCS
  module Engine
    # Applies trades and maintains ledger state.
    #
    # Exposes the core trade application interface used by the simulator.
    #
    # @example
    #   ledger = FCS::Engine::LedgerEngine.new
    #   ledger.apply_trade!(trade)
    class LedgerEngine
      ACCOUNTING_METHOD_AVERAGE = "AVERAGE_COST"
      ACCOUNTING_METHOD_FIFO = "FIFO"

      # @param state [FCS::Engine::LedgerState, nil] optional initial ledger state
      # @param fee_enabled [Boolean] apply fee model if available
      # @param accounting_method [String] accounting method constant
      # @param account_collateral [Hash] collateral per accountId
      # @param max_leverage [FCS::Types::Decimal18, nil] max leverage for risk engine
      # @param risk_engine [FCS::Engine::RiskEngine, nil] custom risk engine
      # @param risk_engine_klass [Class] risk engine class
      # @param decimal_klass [Class] decimal type
      # @param error_klass [Class] error class
      # @param errors [Module] error constants module
      def initialize(
        state: nil,
        fee_enabled: true,
        accounting_method: ACCOUNTING_METHOD_AVERAGE,
        account_collateral: {},
        max_leverage: nil,
        risk_engine: nil,
        risk_engine_klass: FCS::Engine::RiskEngine,
        decimal_klass: FCS::Types::Decimal18,
        error_klass: FCS::Error,
        errors: FCS::Errors
      )
        @decimal_klass = decimal_klass
        @error_klass = error_klass
        @errors = errors
        @fee_enabled = fee_enabled
        @accounting_method = accounting_method
        @state = state || LedgerState.new(position_builder: position_builder_for(accounting_method))
        @risk_engine = risk_engine || risk_engine_klass.new(
          account_collateral: account_collateral,
          risk_config: { maxLeverage: max_leverage }
        )
      end

      attr_reader :state

      # Applies a single trade event to the ledger state.
      #
      # Expected trade shape (minimum):
      # - accountId, marketId, side, quantityBase, priceQuotePerBase
      #
      # @param trade [Hash] trade payload
      # @return [void]
      # @raise [FCS::Error] on validation or risk violations
      # @example
      #   ledger.apply_trade!(
      #     "tradeId" => "t1",
      #     "accountId" => "acc-1",
      #     "marketId" => "btc-usd",
      #     "side" => "BUY",
      #     "quantityBase" => "1.25",
      #     "priceQuotePerBase" => "55000"
      #   )
      def apply_trade!(trade)
        pos = @state.position_for(account_id: trade.fetch("accountId"), market_id: trade.fetch("marketId"))
        validate_long_only_sell!(pos: pos, trade: trade)

        @risk_engine.pre_trade_check!(
          account_id: trade.fetch("accountId"),
          market_id: trade.fetch("marketId"),
          side: trade.fetch("side"),
          quantity: trade.fetch("quantityBase"),
          price: trade.fetch("priceQuotePerBase"),
          position: pos,
          accounting_method: @accounting_method
        )

        if @fee_enabled
          fee_quote = extract_fee_quote(trade)
          pos.apply_fee!(fee_quote) if fee_quote
        end

        case trade.fetch("side")
        when "BUY"
          apply_buy!(pos, trade)
        when "SELL"
          apply_sell!(pos, trade)
        else
          raise @error_klass.new(
            @errors::ERR_VALIDATION,
            "Unsupported side",
            details: { side: trade.fetch("side"), tradeId: trade.fetch("tradeId") }
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
          raise @error_klass.new(
            @errors::ERR_VALIDATION,
            "Unsupported accounting method",
            details: { accountingMethod: accounting_method }
          )
        end
      end

      def apply_buy!(pos, t)
        qty = @decimal_klass.from_string(t.fetch("quantityBase"))
        price = @decimal_klass.from_string(t.fetch("priceQuotePerBase"))
        pos.apply_buy!(buy_qty: qty, buy_price: price)
      end

      def apply_sell!(pos, t)
        qty = @decimal_klass.from_string(t.fetch("quantityBase"))
        price = @decimal_klass.from_string(t.fetch("priceQuotePerBase"))
        pos.apply_sell!(sell_qty: qty, sell_price: price)
      end

      def validate_long_only_sell!(pos:, trade:)
        return unless trade.fetch("side") == "SELL"

        sell_qty = @decimal_klass.from_string(trade.fetch("quantityBase"))
        return if sell_qty.atoms <= pos.qty.atoms

        raise @error_klass.new(
          @errors::ERR_POSITION_NEGATIVE,
          "SELL would make position negative",
          details: {
            accountId: trade.fetch("accountId"),
            marketId: trade.fetch("marketId"),
            tradeId: trade.fetch("tradeId"),
            qty: pos.qty.to_s,
            sellQty: sell_qty.to_s
          }
        )
      end

      def extract_fee_quote(trade)
        fee = trade["fee"]
        return nil unless fee.is_a?(Hash) && fee.key?("amountQuote")

        @decimal_klass.from_string(fee.fetch("amountQuote"))
      end
    end
  end
end
