# frozen_string_literal: true

module FCS
  module Engine
    class RiskEngine
      STATUS_HEALTHY = 'HEALTHY'
      STATUS_MARGIN_CALL = 'MARGIN_CALL'
      STATUS_LIQUIDATABLE = 'LIQUIDATABLE'

      def initialize(account_collateral:, risk_config:)
        @account_collateral = normalize_collateral(account_collateral)
        @risk_config = normalize_config(risk_config)
      end

      def pre_trade_check!(account_id:, market_id:, side:, quantity:, price:, position:, accounting_method:)
        {
          account_id: account_id,
          market_id: market_id,
          side: side,
          quantity: coerce_decimal18(quantity),
          price: coerce_decimal18(price),
          qty_after_trade: coerce_decimal18(position.qty),
          accounting_method: accounting_method
        }
      end

      def evaluate_accounts!(state:, valuation:)
        {
          state: state,
          valuation: valuation,
          statuses: {}
        }
      end

      def liquidation_candidates(health)
        health
      end

      private

      def normalize_collateral(collateral)
        collateral.each_with_object({}) do |(account_id, value), out|
          out[account_id] = coerce_decimal18(value)
        end
      end

      def normalize_config(config)
        config.to_h.each_with_object({}) do |(key, value), out|
          out[key.to_sym] = value.is_a?(String) ? coerce_decimal18(value) : value
        end
      end

      def coerce_decimal18(value)
        return value if value.is_a?(FCS::Types::Decimal18)
        return FCS::Types::Decimal18.from_string(value) if value.is_a?(String)

        raise FCS::Error.new(
          FCS::Errors::ERR_RISK_CONFIG_INVALID,
          'RiskEngine expects Decimal18-compatible values',
          details: { valueClass: value.class.to_s }
        )
      end
    end
  end
end
