# frozen_string_literal: true

module FCS
  module Engine
    # Evaluates margin requirements and liquidation risk.
    #
    # @example
    #   engine = FCS::Engine::RiskEngine.new(account_collateral: {}, risk_config: {})
    #   health = engine.evaluate_accounts!(state: ledger.state, valuation: valuation)
    class RiskEngine
      AccountEntry = Struct.new(
        :maintenance_margin_quote,
        :equity_quote,
        :margin_ratio,
        :status,
        :candidates
      )

      STATUS_HEALTHY = "HEALTHY"
      STATUS_MARGIN_CALL = "MARGIN_CALL"
      STATUS_LIQUIDATABLE = "LIQUIDATABLE"

      # @param account_collateral [Hash] collateral per accountId
      # @param risk_config [Hash] risk model configuration
      def initialize(account_collateral:, risk_config:)
        @account_collateral = normalize_collateral(account_collateral)
        @risk_config = normalize_config(risk_config)
      end

      # Enforces pre-trade risk constraints for shorting and leverage.
      #
      # @param account_id [String]
      # @param market_id [String]
      # @param side [String]
      # @param quantity [String, FCS::Types::Decimal18]
      # @param price [String, FCS::Types::Decimal18]
      # @param position [FCS::Engine::Position, FCS::Engine::PositionFifo]
      # @param accounting_method [String]
      # @return [true]
      # @raise [FCS::Error]
      def pre_trade_check!(account_id:, market_id:, side:, quantity:, price:, position:, accounting_method:)
        qty = coerce_decimal18(quantity)
        projected_qty_atoms = projected_qty_atoms(position: position, side: side, quantity: qty)
        return true unless projected_qty_atoms.negative?

        if accounting_method == FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_FIFO
          raise FCS::Error.new(
            FCS::Errors::ERR_RISK_REJECTION,
            "Short selling is not supported with FIFO accounting",
            details: { accountingMethod: accounting_method, reason: "FIFO_SHORT_FORBIDDEN" }
          )
        end

        collateral = @account_collateral[account_id]
        max_leverage = @risk_config[:max_leverage]
        if collateral.nil? || max_leverage.nil? || collateral.zero?
          raise FCS::Error.new(
            FCS::Errors::ERR_RISK_CONFIG_INVALID,
            "Short selling requires collateralQuote and riskModel.maxLeverage",
            details: { accountId: account_id }
          )
        end

        price_dec = coerce_decimal18(price)
        projected_notional = FCS::Types::Decimal18.new(projected_qty_atoms.abs) * price_dec
        max_notional = collateral * max_leverage
        return true if projected_notional.atoms <= max_notional.atoms

        raise FCS::Error.new(
          FCS::Errors::ERR_RISK_REJECTION,
          "Leverage limit exceeded",
          details: {
            accountId: account_id,
            marketId: market_id,
            projectedNotionalQuote: projected_notional.to_s,
            collateralQuote: collateral.to_s,
            maxLeverage: max_leverage.to_s,
            reason: "MAX_LEVERAGE_EXCEEDED"
          }
        )
      end

      # Evaluates account risk health and liquidation candidates.
      #
      # @param state [FCS::Engine::LedgerState]
      # @param valuation [FCS::Engine::ValuationEngine]
      # @return [Hash]
      def evaluate_accounts!(state:, valuation:)
        maintenance_ratio = @risk_config[:maintenance_margin_ratio]
        accounts = Hash.new do |hash, key|
          hash[key] = AccountEntry.new(
            maintenance_margin_quote: zero,
            equity_quote: @account_collateral.fetch(key, zero),
            candidates: []
          )
        end

        state.positions.each do |key, pos|
          account_id, market_id = key.split("|", 2)
          entry = accounts[account_id]
          snapshot_price = valuation.snapshot_price_for(market_id)
          notional = pos.qty.abs * snapshot_price
          unrealized = valuation.unrealized_pnl_quote(market_id: market_id, position: pos)
          entry.equity_quote += pos.realized_net_quote + unrealized

          if maintenance_ratio
            maintenance = notional * maintenance_ratio
            entry.maintenance_margin_quote += maintenance
          end

          next unless pos.qty.atoms.negative?

          entry.candidates << {
            account_id: account_id,
            market_id: market_id,
            severity: notional,
            seq: 0
          }
        end

        accounts.each_value do |entry|
          maintenance = entry.maintenance_margin_quote
          equity = entry.equity_quote
          entry.margin_ratio = margin_ratio(maintenance: maintenance, equity: equity)
          entry.status = status_for(maintenance: maintenance, equity: equity)
        end

        accounts.transform_values do |entry|
          {
            maintenance_margin_quote: entry.maintenance_margin_quote,
            equity_quote: entry.equity_quote,
            margin_ratio: entry.margin_ratio,
            status: entry.status,
            candidates: entry.candidates
          }
        end
      end

      # Returns liquidation candidates sorted by severity.
      #
      # @param health [Hash]
      # @return [Array<Hash>]
      def liquidation_candidates(health)
        health.each_value.flat_map do |entry|
          next [] unless entry[:status] == STATUS_LIQUIDATABLE

          entry[:candidates]
        end.sort_by do |candidate|
          [-candidate.fetch(:severity).atoms, candidate.fetch(:account_id), candidate.fetch(:market_id),
           candidate.fetch(:seq)]
        end
      end

      private

      def normalize_collateral(collateral)
        collateral.transform_values do |value|
          coerce_decimal18(value)
        end
      end

      def normalize_config(config)
        config.to_h.each_with_object({}) do |(key, value), out|
          normalized_key = key.to_s.gsub(/([a-z])([A-Z])/, '\1_\2').downcase.to_sym
          out[normalized_key] = value.is_a?(String) ? coerce_decimal18(value) : value
        end
      end

      def projected_qty_atoms(position:, side:, quantity:)
        case side
        when "BUY"
          position.qty.atoms + quantity.atoms
        when "SELL"
          position.qty.atoms - quantity.atoms
        else
          position.qty.atoms
        end
      end

      def margin_ratio(maintenance:, equity:)
        return nil if maintenance.zero?

        equity / maintenance
      end

      def status_for(maintenance:, equity:)
        return STATUS_HEALTHY if maintenance.zero?
        return STATUS_LIQUIDATABLE if equity.atoms <= 0
        return STATUS_MARGIN_CALL if equity.atoms < maintenance.atoms

        STATUS_HEALTHY
      end

      def zero
        @zero ||= FCS::Types::Decimal18.new(0)
      end

      def coerce_decimal18(value)
        return value if value.is_a?(FCS::Types::Decimal18)
        return FCS::Types::Decimal18.from_string(value) if value.is_a?(String)

        raise FCS::Error.new(
          FCS::Errors::ERR_RISK_CONFIG_INVALID,
          "RiskEngine expects Decimal18-compatible values",
          details: { valueClass: value.class.to_s }
        )
      end
    end
  end
end
