# frozen_string_literal: true

module FCS
  module Application
    # Builds the simulation result payload for the given input.
    #
    # This is the core execution path used by Runner. It assumes the input is
    # already validated and normalized for determinism.
    #
    # @example
    #   result = FCS::Application::Simulate.new.call(input)
    #   result.fetch("accounts")
    class Simulate
      # @param input [Hash] validated input payload
      # @param explain [Boolean] include explain payload in output
      # @param checkpoint_store [FCS::Application::CheckpointStore, nil] checkpointing support
      # @param input_hash [String, nil] deterministic input hash
      # @return [Hash] result payload
      def call(input, explain: false, checkpoint_store: nil, input_hash: nil)
        fx = FCS::Engine::FXConverter.new(
          price_snapshot: input.fetch('priceSnapshot'),
          usd_enabled: usd_conversion_enabled?(input)
        )

        fee_enabled = input.dig('feeModel', 'enabled')
        accounting_method = input.dig('accountingModel', 'method') || FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_AVERAGE
        account_collateral = extract_account_collateral(input)
        risk_config = extract_risk_config(input)
        risk_engine = FCS::Engine::RiskEngine.new(account_collateral: account_collateral, risk_config: risk_config)

        ledger = FCS::Engine::LedgerEngine.new(
          fee_enabled: fee_enabled,
          accounting_method: accounting_method,
          account_collateral: account_collateral,
          max_leverage: risk_config[:maxLeverage],
          risk_engine: risk_engine
        )

        valuation = FCS::Engine::ValuationEngine.new(price_snapshot: input.fetch('priceSnapshot'))
        timeline_processor = FCS::Application::EventTimelineProcessor.new
        timeline_points = apply_execution_flow!(input: input, ledger: ledger, valuation: valuation,
                                                timeline_processor: timeline_processor,
                                                checkpoint_store: checkpoint_store,
                                                input_hash: input_hash)
        risk_health = risk_engine.evaluate_accounts!(state: ledger.state, valuation: valuation)
        liquidation_candidates = risk_engine.liquidation_candidates(risk_health)
        risk_events_by_account = index_risk_events(liquidation_candidates)

        accounts = build_accounts(
          input,
          ledger.state,
          valuation,
          fx,
          risk_health: risk_health,
          risk_events_by_account: risk_events_by_account,
          explain: explain
        )
        global = consolidate_global(accounts, fx)
        payload = { 'accounts' => accounts, 'global' => global }
        if timeline_points.is_a?(Array)
          payload['timeline'] = {
            'schema_version' => '1.0',
            'points' => timeline_points
          }
        end
        payload
      end

      private

      def build_accounts(input, state, valuation, fx, risk_health:, risk_events_by_account:, explain:)
        account_ids = input.fetch('accounts').map { |a| a.fetch('accountId') }.uniq.sort
        market_ids = input.fetch('markets').map { |m| m.fetch('marketId') }.uniq.sort

        account_ids.map do |account_id|
          markets = build_account_markets(account_id, market_ids, state, valuation, fx, explain)

          totals = sum_market_fields(markets, fx)
          health = risk_health.fetch(account_id, nil)

          payload = {
            'accountId' => account_id,
            'markets' => markets,
            'totals' => totals
          }

          unless health.nil?
            payload['risk'] = {
              'status' => health.fetch(:status),
              'equityQuote' => health.fetch(:equity_quote).to_s,
              'maintenanceMarginQuote' => health.fetch(:maintenance_margin_quote).to_s,
              'marginRatio' => health.fetch(:margin_ratio)&.to_s
            }
          end

          payload['riskEvents'] = risk_events_by_account.fetch(account_id, [])
          payload
        end
      end

      def build_account_markets(account_id, market_ids, state, valuation, fx, explain)
        market_ids.map do |market_id|
          position = state.position_for(account_id: account_id, market_id: market_id)
          build_market_payload(market_id, position, valuation, fx, explain)
        end
      end

      def build_market_payload(market_id, position, valuation, fx, explain)
        unreal = valuation.unrealized_pnl_quote(market_id: market_id, position: position)
        realized = position.realized_pnl_quote
        fees = position.fees_quote
        realized_net = position.realized_net_quote
        total = realized_net + unreal

        payload = {
          'marketId' => market_id,
          'quantity' => position.qty.to_s,
          'avgCost' => position.avg_cost.to_s,
          'realizedPnL' => realized.to_s,
          'unrealizedPnL' => unreal.to_s,
          'realizedPnLQuote' => realized.to_s,
          'feesQuote' => fees.to_s,
          'realizedNetPnLQuote' => realized_net.to_s,
          'unrealizedPnLQuote' => unreal.to_s,
          'totalPnLQuote' => total.to_s,
          'totalPnLUsd' => fx.enabled? ? fx.quote_to_usd(total).to_s : nil
        }

        if explain
          payload['explain'] =
            build_market_explain_payload(market_id, position, valuation, realized, fees, unreal, total)
        end
        payload
      end

      def build_market_explain_payload(market_id, position, valuation, realized, fees, unreal, total)
        snapshot_price = valuation.snapshot_price_for(market_id)
        {
          'snapshotPrice' => snapshot_price.to_s,
          'avgCost' => position.avg_cost.to_s,
          'qty' => position.qty.to_s,
          'realizedPnLQuote' => realized.to_s,
          'feesQuote' => fees.to_s,
          'unrealizedPnLQuote' => unreal.to_s,
          'totalPnLQuote' => total.to_s
        }
      end

      def apply_execution_flow!(input:, ledger:, valuation:, timeline_processor:, checkpoint_store:, input_hash:)
        timeline = input['timeline']

        if timeline.is_a?(Hash) && timeline['events'].is_a?(Array)
          return timeline_processor.call(
            events: timeline.fetch('events'),
            ledger: ledger,
            valuation: valuation,
            checkpoint: input['checkpoint'],
            checkpoint_store: checkpoint_store,
            input_hash: input_hash
          )
        end

        deterministic_batch_trades(input.fetch('trades')).each { |trade| ledger.apply_trade!(trade) }
        nil
      end

      def deterministic_batch_trades(trades)
        FCS::Engine::TradeSorter.new.sort(trades)
      end

      def sum_market_fields(markets, fx)
        z = FCS::Types::Decimal18.new(0)
        realized = z
        fees = z
        realized_net = z
        unreal = z
        total = z

        markets.each do |m|
          realized += FCS::Types::Decimal18.from_string(m['realizedPnLQuote'])
          fees += FCS::Types::Decimal18.from_string(m['feesQuote'])
          realized_net += FCS::Types::Decimal18.from_string(m['realizedNetPnLQuote'])
          unreal += FCS::Types::Decimal18.from_string(m['unrealizedPnLQuote'])
          total += FCS::Types::Decimal18.from_string(m['totalPnLQuote'])
        end

        {
          'realizedPnLQuote' => realized.to_s,
          'feesQuote' => fees.to_s,
          'realizedNetPnLQuote' => realized_net.to_s,
          'unrealizedPnLQuote' => unreal.to_s,
          'totalPnLQuote' => total.to_s,
          'totalPnLUsd' => fx.enabled? ? fx.quote_to_usd(total).to_s : nil
        }
      end

      def consolidate_global(accounts, fx)
        z = FCS::Types::Decimal18.new(0)
        realized = z
        fees = z
        realized_net = z
        unreal = z
        total = z

        accounts.each do |a|
          t = a.fetch('totals')
          realized += FCS::Types::Decimal18.from_string(t['realizedPnLQuote'])
          fees += FCS::Types::Decimal18.from_string(t['feesQuote'])
          realized_net += FCS::Types::Decimal18.from_string(t['realizedNetPnLQuote'])
          unreal += FCS::Types::Decimal18.from_string(t['unrealizedPnLQuote'])
          total += FCS::Types::Decimal18.from_string(t['totalPnLQuote'])
        end

        {
          'realizedPnLQuote' => realized.to_s,
          'feesQuote' => fees.to_s,
          'realizedNetPnLQuote' => realized_net.to_s,
          'unrealizedPnLQuote' => unreal.to_s,
          'totalPnLQuote' => total.to_s,
          'totalPnLUsd' => fx.enabled? ? fx.quote_to_usd(total).to_s : nil
        }
      end

      def extract_account_collateral(input)
        input.fetch('accounts').each_with_object({}) do |account, map|
          collateral = account['collateralQuote']
          next if collateral.nil?

          map[account.fetch('accountId')] = FCS::Types::Decimal18.from_string(collateral)
        end
      end

      def extract_risk_config(input)
        model = input.fetch('riskModel', {})
        config = {}

        max_leverage = model['maxLeverage']
        config[:maxLeverage] = FCS::Types::Decimal18.from_string(max_leverage) unless max_leverage.nil?

        maintenance = model['maintenanceMarginRatio']
        config[:maintenanceMarginRatio] = FCS::Types::Decimal18.from_string(maintenance) unless maintenance.nil?

        liquidation = model['liquidation']
        unless liquidation.nil?
          config[:liquidation] = {
            enabled: liquidation.fetch('enabled', true),
            closeFactor: liquidation['closeFactor']
          }
        end

        config
      end

      def index_risk_events(candidates)
        candidates.each_with_object(Hash.new { |h, k| h[k] = [] }) do |candidate, grouped|
          grouped[candidate.fetch(:account_id)] << {
            'type' => 'RISK_LIQUIDATION_CANDIDATE',
            'reasonCode' => FCS::Errors::ERR_RISK_LIQUIDATABLE,
            'accountId' => candidate.fetch(:account_id),
            'marketId' => candidate.fetch(:market_id),
            'seq' => candidate.fetch(:seq),
            'severity' => candidate.fetch(:severity).to_s
          }
        end
      end

      def usd_conversion_enabled?(input)
        usd_model = input['usdModel']
        return usd_model['enabled'] == true if usd_model.is_a?(Hash)

        fx = input.dig('priceSnapshot', 'fx')
        fx.is_a?(Hash) && fx.key?('quoteUsd') && !fx['quoteUsd'].nil?
      end
    end
  end
end
