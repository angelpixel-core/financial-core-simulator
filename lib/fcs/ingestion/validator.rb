# frozen_string_literal: true

module FCS
  module Ingestion
    # Validates ingestion payloads and raises on invalid input.
    #
    # @example
    #   FCS::Ingestion::Validator.new.validate!(payload)
    class Validator
      SUPPORTED_SCHEMA_VERSIONS = ['1.0'].freeze
      SUPPORTED_ACCOUNTING_METHODS = [
        FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_AVERAGE,
        FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_FIFO
      ].freeze

      # @param h [Hash]
      # @return [true]
      # @raise [FCS::Error]
      def validate!(h)
        validate_schema_version!(h)
        validate_shape!(h)
        validate_accounting_model!(h)
        validate_usd_model!(h)
        validate_risk_model!(h)

        accounts = h.fetch('accounts')
        markets = h.fetch('markets')
        trades = h['trades'] || []

        account_ids = extract_unique_ids!(accounts, 'accountId', code: FCS::Errors::ERR_DUPLICATE_ID)
        market_ids = extract_unique_ids!(markets, 'marketId', code: FCS::Errors::ERR_DUPLICATE_ID)
        validate_account_collateral!(accounts)

        validate_snapshot!(h, market_ids)
        validate_timeline!(h, account_ids: account_ids, market_ids: market_ids)

        effective_trades = timeline_mode_payload?(h) ? timeline_trade_payloads(h) : trades
        validate_trades!(effective_trades, account_ids, market_ids, fee_enabled?(h))
        validate_seq_uniqueness!(effective_trades)

        true
      end

      # @param h [Hash]
      # @return [Hash]
      # @raise [FCS::Error]
      def validate_with_errors!(h)
        validate_schema_version!(h)
        validate_shape!(h)
        validate_accounting_model!(h)
        validate_usd_model!(h)
        validate_risk_model!(h)

        accounts = h.fetch('accounts')
        markets = h.fetch('markets')
        trades = h['trades'] || []

        account_ids = extract_unique_ids!(accounts, 'accountId', code: FCS::Errors::ERR_DUPLICATE_ID)
        market_ids = extract_unique_ids!(markets, 'marketId', code: FCS::Errors::ERR_DUPLICATE_ID)
        validate_account_collateral!(accounts)

        validate_snapshot!(h, market_ids)

        validation_errors = if timeline_mode_payload?(h)
                              validate_timeline_with_errors!(h, account_ids: account_ids, market_ids: market_ids)
                            else
                              validate_trades_with_errors!(trades, account_ids, market_ids, fee_enabled?(h))
                            end

        {
          input: h,
          validation_errors: validation_errors,
          reliable: validation_errors.empty?
        }
      end

      private

      def validate_schema_version!(h)
        sv = h['schemaVersion']
        return if SUPPORTED_SCHEMA_VERSIONS.include?(sv)

        raise FCS::Error.new(
          FCS::Errors::ERR_UNSUPPORTED_SCHEMA,
          t('fcs.ingestion.validator.unsupported_schema_version'),
          details: { schemaVersion: sv, supported: SUPPORTED_SCHEMA_VERSIONS }
        )
      end

      def validate_shape!(h)
        %w[accounts markets priceSnapshot].each do |k|
          raise_invalid!(t('fcs.ingestion.validator.missing_required_field'), field: k) unless h.key?(k)
        end

        unless h['accounts'].is_a?(Array)
          raise_invalid!(t('fcs.ingestion.validator.accounts_must_be_array'),
                         field: 'accounts')
        end
        unless h['markets'].is_a?(Array)
          raise_invalid!(t('fcs.ingestion.validator.markets_must_be_array'),
                         field: 'markets')
        end
        unless h['priceSnapshot'].is_a?(Hash)
          raise_invalid!(t('fcs.ingestion.validator.price_snapshot_must_be_object'),
                         field: 'priceSnapshot')
        end

        timeline = h['timeline']
        unless timeline.nil?
          unless timeline.is_a?(Hash)
            raise_invalid!(t('fcs.ingestion.validator.timeline_must_be_object'),
                           field: 'timeline')
          end
          unless timeline['events'].is_a?(Array)
            raise_invalid!(t('fcs.ingestion.validator.timeline_events_must_be_array'),
                           field: 'timeline.events')
          end
        end

        if timeline.nil?
          raise_invalid!(t('fcs.ingestion.validator.missing_required_field'), field: 'trades') unless h.key?('trades')
          unless h['trades'].is_a?(Array)
            raise_invalid!(t('fcs.ingestion.validator.trades_must_be_array'),
                           field: 'trades')
          end
        elsif h.key?('trades') && !h['trades'].is_a?(Array)
          raise_invalid!(t('fcs.ingestion.validator.trades_must_be_array'), field: 'trades')
        end
      end

      def validate_timeline!(h, account_ids:, market_ids:)
        timeline = h['timeline']
        return if timeline.nil?

        seen_full_idempotency = {}
        seen_source_external = {}
        seen_trade_seq = {}
        seen_timeline_seq = {}
        context = {
          account_ids: account_ids,
          market_ids: market_ids,
          seen_full_idempotency: seen_full_idempotency,
          seen_source_external: seen_source_external,
          seen_trade_seq: seen_trade_seq,
          seen_timeline_seq: seen_timeline_seq
        }
        timeline.fetch('events').each do |event|
          process_timeline_event!(event, context)
        end
      end

      def process_timeline_event!(event, context)
        unless event.is_a?(Hash)
          raise_invalid!(t('fcs.ingestion.validator.timeline_event_must_be_object'),
                         field: 'timeline.events')
        end

        validate_timeline_common_fields!(event)

        idempotency_key = timeline_full_idempotency_key(event)
        source_external_key = timeline_source_external_key(event)
        seen_full_idempotency = context.fetch(:seen_full_idempotency)
        seen_source_external = context.fetch(:seen_source_external)
        seen_trade_seq = context.fetch(:seen_trade_seq)
        seen_timeline_seq = context.fetch(:seen_timeline_seq)
        account_ids = context.fetch(:account_ids)
        market_ids = context.fetch(:market_ids)

        if seen_full_idempotency.key?(idempotency_key)
          validate_timeline_exact_duplicate!(
            event,
            stored_event: seen_full_idempotency.fetch(idempotency_key),
            idempotency_key: idempotency_key
          )

          return
        end

        validate_timeline_partial_collision!(
          event,
          source_external_key: source_external_key,
          seen_source_external: seen_source_external
        )

        seen_full_idempotency[idempotency_key] = event
        seen_source_external[source_external_key] = event.fetch('timelineSeq')
        register_timeline_seq!(seen_timeline_seq, event.fetch('timelineSeq'))

        case event.fetch('eventType')
        when 'PRICE_UPDATED'
          validate_timeline_price_updated!(event, market_ids: market_ids)
        when 'TRADE_APPLIED'
          validate_timeline_trade_applied!(
            event,
            account_ids: account_ids,
            market_ids: market_ids,
            seen_trade_seq: seen_trade_seq
          )
        else
          raise_invalid!(t('fcs.ingestion.validator.timeline_unsupported_event_type'),
                         field: 'timeline.events.eventType',
                         details: { eventType: event.fetch('eventType') })
        end
      end

      def register_timeline_seq!(seen_timeline_seq, current_seq)
        return unless seen_timeline_seq[current_seq]

        raise_invalid!(t('fcs.ingestion.validator.timeline_seq_unique'),
                       field: 'timeline.events.timelineSeq',
                       details: { timelineSeq: current_seq })
      ensure
        seen_timeline_seq[current_seq] = true
      end

      def timeline_full_idempotency_key(event)
        [
          event.fetch('source'),
          event.fetch('externalId'),
          event.fetch('timelineSeq')
        ]
      end

      def timeline_source_external_key(event)
        [
          event.fetch('source'),
          event.fetch('externalId')
        ]
      end

      def validate_timeline_exact_duplicate!(event, stored_event:, idempotency_key:)
        if stored_event != event
          raise_invalid!(
            t('fcs.ingestion.validator.timeline_duplicate_conflict'),
            field: 'timeline.events.idempotencyKey',
            details: {
              source: idempotency_key[0],
              externalId: idempotency_key[1],
              timelineSeq: idempotency_key[2]
            }
          )
        end

        raise_invalid!(
          t('fcs.ingestion.validator.timeline_duplicate_event'),
          field: 'timeline.events.idempotencyKey',
          details: {
            source: idempotency_key[0],
            externalId: idempotency_key[1],
            timelineSeq: idempotency_key[2]
          }
        )
      end

      def validate_timeline_partial_collision!(event, source_external_key:, seen_source_external:)
        previous_seq = seen_source_external[source_external_key]
        return if previous_seq.nil?
        return if previous_seq == event.fetch('timelineSeq')

        raise_invalid!(
          t('fcs.ingestion.validator.timeline_idempotency_collision'),
          field: 'timeline.events.externalId',
          details: {
            source: source_external_key[0],
            externalId: source_external_key[1],
            previousSeq: previous_seq,
            currentSeq: event.fetch('timelineSeq')
          }
        )
      end

      def validate_timeline_common_fields!(event)
        unless event.key?('eventType')
          raise_invalid!(t('fcs.ingestion.validator.timeline_event_type_required'),
                         field: 'timeline.events.eventType')
        end
        unless event.key?('timelineSeq')
          raise_invalid!(t('fcs.ingestion.validator.timeline_seq_required'),
                         field: 'timeline.events.timelineSeq')
        end
        unless event.key?('source')
          raise_invalid!(t('fcs.ingestion.validator.timeline_source_required'),
                         field: 'timeline.events.source')
        end
        unless event.key?('externalId')
          raise_invalid!(t('fcs.ingestion.validator.timeline_external_id_required'),
                         field: 'timeline.events.externalId')
        end
        unless event.key?('timestamp')
          raise_invalid!(t('fcs.ingestion.validator.timeline_timestamp_required'),
                         field: 'timeline.events.timestamp')
        end

        unless non_empty_string?(event['eventType'])
          raise_invalid!(t('fcs.ingestion.validator.timeline_event_type_non_empty'),
                         field: 'timeline.events.eventType')
        end
        unless event['timelineSeq'].is_a?(Integer)
          raise_invalid!(t('fcs.ingestion.validator.timeline_seq_integer'),
                         field: 'timeline.events.timelineSeq')
        end
        unless non_empty_string?(event['source'])
          raise_invalid!(t('fcs.ingestion.validator.timeline_source_non_empty'),
                         field: 'timeline.events.source')
        end
        unless non_empty_string?(event['externalId'])
          raise_invalid!(t('fcs.ingestion.validator.timeline_external_id_non_empty'),
                         field: 'timeline.events.externalId')
        end
        unless non_empty_string?(event['timestamp'])
          raise_invalid!(t('fcs.ingestion.validator.timeline_timestamp_non_empty'),
                         field: 'timeline.events.timestamp')
        end

        return if event['timestamp'].match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)

        raise_invalid!(t('fcs.ingestion.validator.timeline_timestamp_iso'),
                       field: 'timeline.events.timestamp')
      end

      def validate_timeline_price_updated!(event, market_ids:)
        unless event.key?('marketId')
          raise_invalid!(t('fcs.ingestion.validator.timeline_price_updated_market_required'),
                         field: 'timeline.events.marketId')
        end
        unless event.key?('priceQuotePerBase')
          raise_invalid!(t('fcs.ingestion.validator.timeline_price_updated_price_required'),
                         field: 'timeline.events.priceQuotePerBase')
        end

        unless non_empty_string?(event['marketId'])
          raise_invalid!(t('fcs.ingestion.validator.timeline_price_updated_market_non_empty'),
                         field: 'timeline.events.marketId')
        end
        unless market_ids.include?(event['marketId'])
          raise FCS::Error.new(FCS::Errors::ERR_UNKNOWN_REFERENCE,
                               t('fcs.ingestion.validator.unknown_market_id'),
                               details: { marketId: event['marketId'] })
        end
        validate_positive_decimal_string!(
          event['priceQuotePerBase'],
          field: 'timeline.events.priceQuotePerBase',
          context: { marketId: event['marketId'] }
        )
      end

      def validate_timeline_trade_applied!(event, account_ids:, market_ids:, seen_trade_seq:)
        trade = event['trade']
        unless trade.is_a?(Hash)
          raise_invalid!(t('fcs.ingestion.validator.timeline_trade_required'),
                         field: 'timeline.events.trade')
        end

        %w[tradeId accountId marketId timestamp seq side quantityBase priceQuotePerBase].each do |field|
          unless trade.key?(field)
            raise_invalid!(t('fcs.ingestion.validator.timeline_trade_field_required', field: field),
                           field: "timeline.events.trade.#{field}")
          end
        end

        unless non_empty_string?(trade['tradeId'])
          raise_invalid!(t('fcs.ingestion.validator.timeline_trade_id_non_empty'),
                         field: 'timeline.events.trade.tradeId')
        end
        unless non_empty_string?(trade['accountId'])
          raise_invalid!(t('fcs.ingestion.validator.timeline_trade_account_non_empty'),
                         field: 'timeline.events.trade.accountId')
        end
        unless account_ids.include?(trade['accountId'])
          raise FCS::Error.new(FCS::Errors::ERR_UNKNOWN_REFERENCE,
                               t('fcs.ingestion.validator.unknown_account_id'),
                               details: { accountId: trade['accountId'] })
        end
        unless non_empty_string?(trade['marketId'])
          raise_invalid!(t('fcs.ingestion.validator.timeline_trade_market_non_empty'),
                         field: 'timeline.events.trade.marketId')
        end
        unless market_ids.include?(trade['marketId'])
          raise FCS::Error.new(FCS::Errors::ERR_UNKNOWN_REFERENCE,
                               t('fcs.ingestion.validator.unknown_market_id'),
                               details: { marketId: trade['marketId'] })
        end
        unless trade['seq'].is_a?(Integer)
          raise_invalid!(t('fcs.ingestion.validator.timeline_trade_seq_integer'),
                         field: 'timeline.events.trade.seq')
        end
        unless trade['timestamp'].is_a?(Integer)
          raise_invalid!(t('fcs.ingestion.validator.timeline_trade_timestamp_integer'),
                         field: 'timeline.events.trade.timestamp')
        end

        trade_seq_key = [trade['accountId'], trade['marketId'], trade['seq']]
        if seen_trade_seq[trade_seq_key]
          raise FCS::Error.new(
            FCS::Errors::ERR_DUPLICATE_SEQ,
            t('fcs.ingestion.validator.duplicate_seq_account_market'),
            details: { accountId: trade['accountId'], marketId: trade['marketId'], seq: trade['seq'] }
          )
        end
        seen_trade_seq[trade_seq_key] = true

        unless %w[
          BUY SELL
        ].include?(trade['side'])
          raise_invalid!(t('fcs.ingestion.validator.invalid_side'),
                         field: 'timeline.events.trade.side', details: { side: trade['side'] })
        end

        validate_positive_decimal_string!(trade['quantityBase'],
                                          field: 'timeline.events.trade.quantityBase',
                                          context: { tradeId: trade['tradeId'] })
        validate_positive_decimal_string!(trade['priceQuotePerBase'],
                                          field: 'timeline.events.trade.priceQuotePerBase',
                                          context: { tradeId: trade['tradeId'] })
      end

      def validate_accounting_model!(h)
        model = h['accountingModel']
        return if model.nil?

        unless model.is_a?(Hash)
          raise_invalid!(t('fcs.ingestion.validator.accounting_model_must_be_object'),
                         field: 'accountingModel')
        end

        method = model['method']
        return if method.nil?

        return if SUPPORTED_ACCOUNTING_METHODS.include?(method)

        raise_invalid!(
          t('fcs.ingestion.validator.unsupported_accounting_method'),
          field: 'accountingModel.method',
          details: { method: method, supported: SUPPORTED_ACCOUNTING_METHODS }
        )
      end

      def validate_risk_model!(h)
        model = h['riskModel']
        return if model.nil?

        unless model.is_a?(Hash)
          raise_invalid!(t('fcs.ingestion.validator.risk_model_must_be_object'),
                         field: 'riskModel')
        end

        max_leverage = model['maxLeverage']
        unless max_leverage.nil?
          validate_positive_decimal_string!(max_leverage, field: 'riskModel.maxLeverage',
                                                          context: {})
        end

        maintenance = model['maintenanceMarginRatio']
        if model.key?('maintenanceMarginRatio') && maintenance.nil?
          raise_invalid!(t('fcs.ingestion.validator.risk_model_maintenance_required'),
                         field: 'riskModel.maintenanceMarginRatio')
        end

        unless maintenance.nil?
          validate_ratio_decimal_string!(
            maintenance,
            field: 'riskModel.maintenanceMarginRatio',
            context: {},
            max: '0.95'
          )
        end

        liquidation = model['liquidation']
        return if liquidation.nil?

        unless liquidation.is_a?(Hash)
          raise_invalid!(t('fcs.ingestion.validator.risk_model_liquidation_object'),
                         field: 'riskModel.liquidation')
        end

        enabled = liquidation['enabled']
        unless enabled.nil? || enabled == true || enabled == false
          raise_invalid!(t('fcs.ingestion.validator.risk_model_liquidation_enabled_boolean'),
                         field: 'riskModel.liquidation.enabled')
        end

        close_factor = liquidation['closeFactor']
        unless liquidation.key?('closeFactor')
          raise_invalid!(t('fcs.ingestion.validator.risk_model_close_factor_required'),
                         field: 'riskModel.liquidation.closeFactor')
        end

        if liquidation.key?('closeFactor') && close_factor.nil?
          raise_invalid!(t('fcs.ingestion.validator.risk_model_close_factor_required'),
                         field: 'riskModel.liquidation.closeFactor')
        end

        return if close_factor.nil?

        validate_ratio_decimal_string!(
          close_factor,
          field: 'riskModel.liquidation.closeFactor',
          context: {},
          max: '1'
        )
      end

      def validate_account_collateral!(accounts)
        accounts.each do |account|
          collateral = account['collateralQuote']
          next if collateral.nil?

          validate_non_negative_decimal_string!(
            collateral,
            field: 'accounts.collateralQuote',
            context: { accountId: account['accountId'] }
          )
        end
      end

      def extract_unique_ids!(arr, key, code:)
        ids = arr.map { |x| x[key] }
        if ids.any?(&:nil?) || ids.any? { |v| !v.is_a?(String) || v.strip.empty? }
          raise_invalid!(t('fcs.ingestion.validator.missing_or_invalid_id'), field: key)
        end

        dup = ids.group_by(&:itself).find { |_k, v| v.size > 1 }&.first
        if dup
          raise FCS::Error.new(code, t('fcs.ingestion.validator.duplicate_id'),
                               details: { field: key, value: dup })
        end

        ids.to_set
      end

      def validate_snapshot!(h, market_ids)
        snap = h['priceSnapshot']
        unless non_empty_string?(snap['valuationTimestamp'])
          raise FCS::Error.new(
            FCS::Errors::ERR_MISSING_SNAPSHOT,
            t('fcs.ingestion.validator.missing_snapshot_timestamp'),
            details: { missingField: 'priceSnapshot.valuationTimestamp' }
          )
        end

        unless snap['valuationTimestamp'].match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
          raise_invalid!(t('fcs.ingestion.validator.invalid_snapshot_timestamp_format'),
                         field: 'priceSnapshot.valuationTimestamp')
        end

        prices = snap['prices']
        unless prices.is_a?(Array)
          raise FCS::Error.new(FCS::Errors::ERR_MISSING_SNAPSHOT, t('fcs.ingestion.validator.missing_snapshot_prices'),
                               details: {})
        end

        price_map = {}
        seen_snapshot_markets = {}
        prices.each do |p|
          unless p.is_a?(Hash)
            raise_invalid!(t('fcs.ingestion.validator.snapshot_price_item_object'),
                           field: 'priceSnapshot.prices')
          end

          mid = p['marketId']
          unless non_empty_string?(mid)
            raise_invalid!(t('fcs.ingestion.validator.missing_or_invalid_snapshot_market_id'),
                           field: 'priceSnapshot.prices.marketId')
          end

          if seen_snapshot_markets[mid]
            raise_invalid!(t('fcs.ingestion.validator.duplicate_snapshot_market_id'),
                           field: 'priceSnapshot.prices.marketId',
                           details: { marketId: mid })
          end

          seen_snapshot_markets[mid] = true
          price = p['priceQuotePerBase']
          price_map[mid] = price
        end

        missing = market_ids.reject { |mid| price_map.key?(mid) }
        unless missing.empty?
          raise FCS::Error.new(
            FCS::Errors::ERR_MISSING_SNAPSHOT,
            t('fcs.ingestion.validator.snapshot_missing_markets'),
            details: { missingMarkets: missing.to_a }
          )
        end

        # validate price > 0, and disallow floats
        prices.each do |p|
          mid = p['marketId']
          v = p['priceQuotePerBase']
          validate_positive_decimal_string!(v, field: 'priceSnapshot.prices.priceQuotePerBase',
                                               context: { marketId: mid })
        end

        fx = snap['fx']
        if usd_conversion_enabled?(h) && (fx.nil? || !fx.is_a?(Hash) || !fx.key?('quoteUsd') || fx['quoteUsd'].nil?)
          raise_missing_fx_for_usd_enabled!
        end

        return if fx.nil?
        return if usd_model_explicitly_disabled?(h)

        unless fx.is_a?(Hash)
          raise FCS::Error.new(
            FCS::Errors::ERR_MISSING_SNAPSHOT,
            t('fcs.ingestion.validator.missing_snapshot_fx_payload'),
            details: { missingField: 'priceSnapshot.fx.quoteUsd' }
          )
        end

        unless fx.key?('quoteUsd') && !fx['quoteUsd'].nil?
          raise FCS::Error.new(
            FCS::Errors::ERR_MISSING_SNAPSHOT,
            t('fcs.ingestion.validator.missing_snapshot_fx_rate'),
            details: { missingField: 'priceSnapshot.fx.quoteUsd' }
          )
        end

        q = fx['quoteUsd']
        validate_positive_decimal_string!(q, field: 'priceSnapshot.fx.quoteUsd', context: {})
      end

      def validate_usd_model!(h)
        model = h['usdModel']
        return if model.nil?

        unless model.is_a?(Hash)
          raise_invalid!(t('fcs.ingestion.validator.usd_model_must_be_object'),
                         field: 'usdModel')
        end
        unless model.key?('enabled')
          raise_invalid!(t('fcs.ingestion.validator.usd_model_enabled_required'), field: 'usdModel.enabled')
        end

        enabled = model['enabled']
        return if [true, false].include?(enabled)

        raise_invalid!(t('fcs.ingestion.validator.usd_model_enabled_boolean'), field: 'usdModel.enabled')
      end

      def usd_conversion_enabled?(h)
        model = h['usdModel']
        return model.is_a?(Hash) && model['enabled'] == true if h.key?('usdModel')

        fx = h.dig('priceSnapshot', 'fx')
        fx.is_a?(Hash) && fx.key?('quoteUsd') && !fx['quoteUsd'].nil?
      end

      def usd_model_explicitly_disabled?(h)
        model = h['usdModel']
        model.is_a?(Hash) && model['enabled'] == false
      end

      def raise_missing_fx_for_usd_enabled!
        raise FCS::Error.new(
          FCS::Errors::ERR_MISSING_SNAPSHOT,
          t('fcs.ingestion.validator.missing_snapshot_fx_rate'),
          details: {
            missingField: 'priceSnapshot.fx.quoteUsd',
            what_happened: t('fcs.ingestion.validator.missing_fx_what_happened'),
            impact: t('fcs.ingestion.validator.missing_fx_impact'),
            next_action: t('fcs.ingestion.validator.missing_fx_next_action')
          }
        )
      end

      def validate_trades!(trades, account_ids, market_ids, fee_enabled)
        trades.each do |trade|
          validate_trade!(trade, account_ids, market_ids, fee_enabled)
        end
      end

      def validate_trades_with_errors!(trades, account_ids, market_ids, fee_enabled)
        errors = []
        seen_seq = {}

        trades.each_with_index do |trade, index|
          trade_errors = []

          unless trade.is_a?(Hash)
            message = t('fcs.ingestion.validator.trades_item_object')
            append_trade_error(
              errors,
              trade_errors,
              field: 'trades',
              message: message,
              code: FCS::Errors::ERR_VALIDATION,
              trade: trade,
              row_index: index,
              timeline_context: nil
            )

            trades[index] = { 'valid' => false, 'validation_errors' => trade_errors }
            next
          end

          collect_trade_errors(
            errors,
            trade_errors,
            trade: trade,
            account_ids: account_ids,
            market_ids: market_ids,
            fee_enabled: fee_enabled,
            row_index: index,
            timeline_context: nil
          )

          register_trade_seq_error(
            errors,
            trade_errors,
            trade: trade,
            seen_seq: seen_seq,
            row_index: index,
            timeline_context: nil
          )

          annotate_trade!(trade, trade_errors)
        end

        errors
      end

      def validate_trade!(trade, account_ids, market_ids, fee_enabled)
        raise_invalid!(t('fcs.ingestion.validator.trades_item_object'), field: 'trades') unless trade.is_a?(Hash)

        trade_id = trade['tradeId']
        unless non_empty_string?(trade_id)
          raise_invalid!(t('fcs.ingestion.validator.missing_trade_id'),
                         field: 'tradeId')
        end

        aid = trade['accountId']
        mid = trade['marketId']

        unless account_ids.include?(aid)
          raise FCS::Error.new(FCS::Errors::ERR_UNKNOWN_REFERENCE,
                               t('fcs.ingestion.validator.unknown_account_id'),
                               details: { accountId: aid })
        end
        unless market_ids.include?(mid)
          raise FCS::Error.new(FCS::Errors::ERR_UNKNOWN_REFERENCE,
                               t('fcs.ingestion.validator.unknown_market_id'),
                               details: { marketId: mid })
        end

        side = trade['side']
        raise_invalid!(t('fcs.ingestion.validator.invalid_side'), field: 'side', details: { side: side }) unless %w[BUY
                                                                                                                    SELL].include?(side)

        validate_positive_decimal_string!(trade['quantityBase'], field: 'quantityBase',
                                                                 context: { tradeId: trade_id })
        validate_positive_decimal_string!(trade['priceQuotePerBase'], field: 'priceQuotePerBase',
                                                                      context: { tradeId: trade_id })

        if fee_enabled && trade['fee'].is_a?(Hash) && trade['fee'].key?('amountQuote')
          value = trade['fee']['amountQuote']
          validate_non_negative_decimal_string!(value, field: 'fee.amountQuote', context: { tradeId: trade_id })
        end

        timestamp = trade['timestamp']
        unless timestamp.is_a?(Integer)
          raise_invalid!(t('fcs.ingestion.validator.missing_or_invalid_timestamp'),
                         field: 'timestamp', details: { tradeId: trade_id })
        end

        seq = trade['seq']
        return if seq.is_a?(Integer)

        raise_invalid!(t('fcs.ingestion.validator.missing_seq'), field: 'seq',
                                                                 details: { tradeId: trade_id })
      end

      def validate_seq_uniqueness!(trades)
        seen = {}
        trades.each do |t|
          key = [t['accountId'], t['marketId'], t['seq']]
          if seen[key]
            raise FCS::Error.new(
              FCS::Errors::ERR_DUPLICATE_SEQ,
              t('fcs.ingestion.validator.duplicate_seq_account_market'),
              details: { accountId: t['accountId'], marketId: t['marketId'], seq: t['seq'] }
            )
          end
          seen[key] = true
        end
      end

      def validate_timeline_with_errors!(h, account_ids:, market_ids:)
        timeline = h['timeline']
        return [] if timeline.nil?

        seen_full_idempotency = {}
        seen_source_external = {}
        seen_trade_seq = {}
        seen_timeline_seq = {}
        errors = []

        context = {
          account_ids: account_ids,
          market_ids: market_ids,
          fee_enabled: fee_enabled?(h),
          seen_full_idempotency: seen_full_idempotency,
          seen_source_external: seen_source_external,
          seen_trade_seq: seen_trade_seq,
          seen_timeline_seq: seen_timeline_seq,
          errors: errors
        }

        timeline.fetch('events').each_with_index do |event, index|
          process_timeline_event_with_errors!(event, index, context)
        end

        errors
      end

      def process_timeline_event_with_errors!(event, index, context)
        unless event.is_a?(Hash)
          raise_invalid!(t('fcs.ingestion.validator.timeline_event_must_be_object'),
                         field: 'timeline.events')
        end

        validate_timeline_common_fields!(event)

        idempotency_key = timeline_full_idempotency_key(event)
        source_external_key = timeline_source_external_key(event)
        seen_full_idempotency = context.fetch(:seen_full_idempotency)
        seen_source_external = context.fetch(:seen_source_external)
        seen_trade_seq = context.fetch(:seen_trade_seq)
        seen_timeline_seq = context.fetch(:seen_timeline_seq)
        account_ids = context.fetch(:account_ids)
        market_ids = context.fetch(:market_ids)
        fee_enabled = context.fetch(:fee_enabled)
        errors = context.fetch(:errors)

        if seen_full_idempotency.key?(idempotency_key)
          validate_timeline_exact_duplicate!(
            event,
            stored_event: seen_full_idempotency.fetch(idempotency_key),
            idempotency_key: idempotency_key
          )

          return
        end

        validate_timeline_partial_collision!(
          event,
          source_external_key: source_external_key,
          seen_source_external: seen_source_external
        )

        seen_full_idempotency[idempotency_key] = event
        seen_source_external[source_external_key] = event.fetch('timelineSeq')
        register_timeline_seq!(seen_timeline_seq, event.fetch('timelineSeq'))

        case event.fetch('eventType')
        when 'PRICE_UPDATED'
          validate_timeline_price_updated!(event, market_ids: market_ids)
        when 'TRADE_APPLIED'
          validate_timeline_trade_applied_with_errors!(
            event,
            account_ids: account_ids,
            market_ids: market_ids,
            fee_enabled: fee_enabled,
            seen_trade_seq: seen_trade_seq,
            errors: errors,
            row_index: index
          )
        else
          raise_invalid!(t('fcs.ingestion.validator.timeline_unsupported_event_type'),
                         field: 'timeline.events.eventType',
                         details: { eventType: event.fetch('eventType') })
        end
      end

      def validate_timeline_trade_applied_with_errors!(event, account_ids:, market_ids:, fee_enabled:, seen_trade_seq:,
                                                       errors:, row_index:)
        trade = event['trade']
        event_type = event['eventType']
        timeline_seq = event['timelineSeq']
        occurred_at = normalize_occurred_at(event['timestamp'])
        timeline_context = {
          timeline_seq: timeline_seq,
          event_type: event_type,
          occurred_at: occurred_at
        }

        trade_errors = []

        unless trade.is_a?(Hash)
          message = t('fcs.ingestion.validator.timeline_trade_required')
          append_trade_error(
            errors,
            trade_errors,
            field: 'timeline.events.trade',
            message: message,
            code: FCS::Errors::ERR_VALIDATION,
            trade: trade,
            row_index: row_index,
            timeline_context: timeline_context
          )

          event['trade'] = { 'valid' => false, 'validation_errors' => trade_errors }
          return
        end

        %w[tradeId accountId marketId timestamp seq side quantityBase priceQuotePerBase].each do |field|
          next if trade.key?(field)

          message = t('fcs.ingestion.validator.timeline_trade_field_required', field: field)
          append_trade_error(
            errors,
            trade_errors,
            field: "timeline.events.trade.#{field}",
            message: message,
            code: FCS::Errors::ERR_VALIDATION,
            trade: trade,
            row_index: row_index,
            timeline_context: timeline_context
          )
        end

        collect_trade_errors(
          errors,
          trade_errors,
          trade: trade,
          account_ids: account_ids,
          market_ids: market_ids,
          fee_enabled: fee_enabled,
          row_index: row_index,
          timeline_context: timeline_context,
          field_prefix: 'timeline.events.trade'
        )

        register_trade_seq_error(
          errors,
          trade_errors,
          trade: trade,
          seen_seq: seen_trade_seq,
          row_index: row_index,
          timeline_context: timeline_context,
          field_prefix: 'timeline.events.trade.seq'
        )

        annotate_trade!(trade, trade_errors)
      end

      def collect_trade_errors(errors, trade_errors, trade:, account_ids:, market_ids:, fee_enabled:, row_index:,
                               timeline_context:, field_prefix: nil)
        prefix = field_prefix ? "#{field_prefix}." : ''

        trade_id = trade['tradeId']
        if !(field_prefix && !trade.key?('tradeId')) && !non_empty_string?(trade_id)
          message = if field_prefix
                      t('fcs.ingestion.validator.timeline_trade_id_non_empty')
                    else
                      t('fcs.ingestion.validator.missing_trade_id')
                    end
          append_trade_error(
            errors,
            trade_errors,
            field: "#{prefix}tradeId",
            message: message,
            code: FCS::Errors::ERR_VALIDATION,
            trade: trade,
            row_index: row_index,
            timeline_context: timeline_context
          )
        end

        aid = trade['accountId']
        if field_prefix
          if trade.key?('accountId') && !non_empty_string?(aid)
            message = t('fcs.ingestion.validator.timeline_trade_account_non_empty')
            append_trade_error(
              errors,
              trade_errors,
              field: "#{prefix}accountId",
              message: message,
              code: FCS::Errors::ERR_VALIDATION,
              trade: trade,
              row_index: row_index,
              timeline_context: timeline_context
            )
          end

          unless account_ids.include?(aid)
            message = t('fcs.ingestion.validator.unknown_account_id')
            append_trade_error(
              errors,
              trade_errors,
              field: "#{prefix}accountId",
              message: message,
              code: FCS::Errors::ERR_UNKNOWN_REFERENCE,
              trade: trade,
              row_index: row_index,
              timeline_context: timeline_context
            )
          end
        elsif !account_ids.include?(aid)
          message = t('fcs.ingestion.validator.unknown_account_id')
          append_trade_error(
            errors,
            trade_errors,
            field: "#{prefix}accountId",
            message: message,
            code: FCS::Errors::ERR_UNKNOWN_REFERENCE,
            trade: trade,
            row_index: row_index,
            timeline_context: timeline_context
          )
        end

        mid = trade['marketId']
        if field_prefix
          if trade.key?('marketId') && !non_empty_string?(mid)
            message = t('fcs.ingestion.validator.timeline_trade_market_non_empty')
            append_trade_error(
              errors,
              trade_errors,
              field: "#{prefix}marketId",
              message: message,
              code: FCS::Errors::ERR_VALIDATION,
              trade: trade,
              row_index: row_index,
              timeline_context: timeline_context
            )
          end

          unless market_ids.include?(mid)
            message = t('fcs.ingestion.validator.unknown_market_id')
            append_trade_error(
              errors,
              trade_errors,
              field: "#{prefix}marketId",
              message: message,
              code: FCS::Errors::ERR_UNKNOWN_REFERENCE,
              trade: trade,
              row_index: row_index,
              timeline_context: timeline_context
            )
          end
        elsif !market_ids.include?(mid)
          message = t('fcs.ingestion.validator.unknown_market_id')
          append_trade_error(
            errors,
            trade_errors,
            field: "#{prefix}marketId",
            message: message,
            code: FCS::Errors::ERR_UNKNOWN_REFERENCE,
            trade: trade,
            row_index: row_index,
            timeline_context: timeline_context
          )
        end

        side = trade['side']
        unless %w[BUY SELL].include?(side)
          message = t('fcs.ingestion.validator.invalid_side')
          append_trade_error(
            errors,
            trade_errors,
            field: "#{prefix}side",
            message: message,
            code: FCS::Errors::ERR_VALIDATION,
            trade: trade,
            row_index: row_index,
            timeline_context: timeline_context
          )
        end

        validate_trade_decimal_field(errors, trade_errors,
                                     value: trade['quantityBase'],
                                     field: "#{prefix}quantityBase",
                                     field_key: 'quantityBase',
                                     trade: trade,
                                     row_index: row_index,
                                     timeline_context: timeline_context)

        validate_trade_decimal_field(errors, trade_errors,
                                     value: trade['priceQuotePerBase'],
                                     field: "#{prefix}priceQuotePerBase",
                                     field_key: 'priceQuotePerBase',
                                     trade: trade,
                                     row_index: row_index,
                                     timeline_context: timeline_context)

        if fee_enabled && trade['fee'].is_a?(Hash) && trade['fee'].key?('amountQuote')
          begin
            validate_non_negative_decimal_string!(trade['fee']['amountQuote'],
                                                  field: "#{prefix}fee.amountQuote",
                                                  context: { tradeId: trade_id })
          rescue FCS::Error => e
            append_trade_error(
              errors,
              trade_errors,
              field: "#{prefix}fee.amountQuote",
              message: e.message,
              code: e.code,
              trade: trade,
              row_index: row_index,
              timeline_context: timeline_context
            )
          end
        end

        timestamp = trade['timestamp']
        if field_prefix
          if trade.key?('timestamp') && !timestamp.is_a?(Integer)
            message = t('fcs.ingestion.validator.timeline_trade_timestamp_integer')
            append_trade_error(
              errors,
              trade_errors,
              field: "#{prefix}timestamp",
              message: message,
              code: FCS::Errors::ERR_VALIDATION,
              trade: trade,
              row_index: row_index,
              timeline_context: timeline_context
            )
          end
        else
          unless timestamp.is_a?(Integer)
            message = t('fcs.ingestion.validator.missing_or_invalid_timestamp')
            append_trade_error(
              errors,
              trade_errors,
              field: "#{prefix}timestamp",
              message: message,
              code: FCS::Errors::ERR_VALIDATION,
              trade: trade,
              row_index: row_index,
              timeline_context: timeline_context
            )
          end
        end

        seq = trade['seq']
        if field_prefix
          if trade.key?('seq') && !seq.is_a?(Integer)
            message = t('fcs.ingestion.validator.timeline_trade_seq_integer')
            append_trade_error(
              errors,
              trade_errors,
              field: "#{prefix}seq",
              message: message,
              code: FCS::Errors::ERR_VALIDATION,
              trade: trade,
              row_index: row_index,
              timeline_context: timeline_context
            )
          end
        else
          unless seq.is_a?(Integer)
            message = t('fcs.ingestion.validator.missing_seq')
            append_trade_error(
              errors,
              trade_errors,
              field: "#{prefix}seq",
              message: message,
              code: FCS::Errors::ERR_VALIDATION,
              trade: trade,
              row_index: row_index,
              timeline_context: timeline_context
            )
          end
        end
      end

      def register_trade_seq_error(errors, trade_errors, trade:, seen_seq:, row_index:, timeline_context:,
                                   field_prefix: nil)
        account_id = trade.is_a?(Hash) ? trade['accountId'] : nil
        market_id = trade.is_a?(Hash) ? trade['marketId'] : nil
        seq = trade.is_a?(Hash) ? trade['seq'] : nil
        return unless account_id && market_id && seq.is_a?(Integer)

        key = [account_id, market_id, seq]
        return unless seen_seq[key]

        message = t('fcs.ingestion.validator.duplicate_seq_account_market')
        field = field_prefix || 'seq'
        append_trade_error(
          errors,
          trade_errors,
          field: field,
          message: message,
          code: FCS::Errors::ERR_DUPLICATE_SEQ,
          trade: trade,
          row_index: row_index,
          timeline_context: timeline_context
        )
      ensure
        seen_seq[key] = true if account_id && market_id && seq.is_a?(Integer)
      end

      def validate_trade_decimal_field(errors, trade_errors, value:, field:, trade:, row_index:, timeline_context:,
                                       field_key: nil)
        return if field_key && !trade.key?(field_key)

        validate_positive_decimal_string!(value, field: field, context: { tradeId: trade['tradeId'] })
      rescue FCS::Error => e
        append_trade_error(
          errors,
          trade_errors,
          field: field,
          message: e.message,
          code: e.code,
          trade: trade,
          row_index: row_index,
          timeline_context: timeline_context
        )
      end

      def append_trade_error(errors, trade_errors, field:, message:, code:, trade:, row_index:, timeline_context:)
        occurred_at = timeline_context&.fetch(:occurred_at, nil)
        occurred_at ||= trade_occurred_at(trade)
        errors << {
          source: 'trade',
          field: field,
          message: message,
          code: code,
          trade_id: trade.is_a?(Hash) ? trade['tradeId'] : nil,
          account_id: trade.is_a?(Hash) ? trade['accountId'] : nil,
          market_id: trade.is_a?(Hash) ? trade['marketId'] : nil,
          timeline_seq: timeline_context&.fetch(:timeline_seq, nil),
          event_type: timeline_context&.fetch(:event_type, nil),
          row_index: row_index,
          occurred_at: occurred_at
        }

        trade_errors << {
          'field' => field,
          'message' => message,
          'code' => code
        }
      end

      def annotate_trade!(trade, trade_errors)
        return unless trade.is_a?(Hash)

        trade['valid'] = trade_errors.empty?
        trade['validation_errors'] = trade_errors
      end

      def trade_occurred_at(trade)
        return nil unless trade.is_a?(Hash)

        normalize_occurred_at(trade['timestamp'])
      end

      def normalize_occurred_at(raw)
        return nil if raw.nil?

        return Time.at(normalize_epoch(raw)).utc.iso8601 if raw.is_a?(Numeric)

        raw_string = raw.to_s.strip
        return nil if raw_string.empty?

        return Time.at(normalize_epoch(raw_string.to_i)).utc.iso8601 if raw_string.match?(/\A\d+\z/)

        return raw_string if raw_string.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)

        nil
      end

      def normalize_epoch(value)
        numeric_value = value.to_f
        return numeric_value / 1000.0 if numeric_value >= 1_000_000_000_000

        numeric_value
      end

      def timeline_mode_payload?(h)
        h['timeline'].is_a?(Hash) && h.dig('timeline', 'events').is_a?(Array)
      end

      def timeline_trade_payloads(h)
        h.fetch('timeline')
         .fetch('events')
         .select { |event| event.is_a?(Hash) && event['eventType'] == 'TRADE_APPLIED' }
         .map { |event| event['trade'] }
      end

      def fee_enabled?(h)
        fm = h['feeModel']
        return true if fm.nil?

        v = fm['enabled']
        v.nil? || !!v
      end

      def validate_positive_decimal_string!(v, field:, context:)
        validate_decimal_string!(v, field:, context:, allow_zero: false)
      end

      def validate_non_negative_decimal_string!(v, field:, context:)
        validate_decimal_string!(v, field:, context:, allow_zero: true)
      end

      def validate_ratio_decimal_string!(v, field:, context:, max: '1')
        validate_decimal_string!(v, field:, context:, allow_zero: false)
        parsed = FCS::Types::Decimal18.from_string(v)
        max_decimal = FCS::Types::Decimal18.from_string(max)
        return if parsed.atoms <= max_decimal.atoms

        raise_invalid!(t('fcs.ingestion.validator.must_be_lte', max: max),
                       field: field, details: context.merge(value: v))
      end

      def validate_decimal_string!(v, field:, context:, allow_zero:)
        if v.is_a?(Float)
          raise FCS::Error.new(FCS::Errors::ERR_INVALID_NUMBER, t('fcs.ingestion.validator.float_not_allowed'),
                               details: context.merge(field: field))
        end

        unless v.is_a?(String) && v.match?(/\A\d+(\.\d+)?\z/)
          raise_invalid!(t('fcs.ingestion.validator.invalid_decimal_string'),
                         field: field, details: context.merge(value: v))
        end

        parsed = FCS::Types::Decimal18.from_string(v)
        return unless !allow_zero && parsed.zero?

        raise_invalid!(t('fcs.ingestion.validator.must_be_gt_zero'),
                       field: field, details: context.merge(value: v))
      end

      def non_empty_string?(v)
        v.is_a?(String) && !v.strip.empty?
      end

      def raise_invalid!(msg, field:, details: {})
        raise FCS::Error.new(FCS::Errors::ERR_VALIDATION, msg, details: details.merge(field: field))
      end

      def t(key, **opts)
        ::I18n.t(key, **opts)
      end
    end
  end
end
