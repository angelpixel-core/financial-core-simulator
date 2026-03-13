# frozen_string_literal: true

module FCS
  module Ingestion
    class Validator
      SUPPORTED_SCHEMA_VERSIONS = ['1.0'].freeze
      SUPPORTED_ACCOUNTING_METHODS = [
        FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_AVERAGE,
        FCS::Engine::LedgerEngine::ACCOUNTING_METHOD_FIFO
      ].freeze

      def validate!(h)
        validate_schema_version!(h)
        validate_shape!(h)
        validate_accounting_model!(h)
        validate_risk_model!(h)

        accounts = h.fetch('accounts')
        markets  = h.fetch('markets')
        trades   = h.fetch('trades')

        account_ids = extract_unique_ids!(accounts, 'accountId', code: FCS::Errors::ERR_DUPLICATE_ID)
        market_ids  = extract_unique_ids!(markets, 'marketId', code: FCS::Errors::ERR_DUPLICATE_ID)
        validate_account_collateral!(accounts)

        validate_snapshot!(h, market_ids)
        validate_timeline!(h)

        validate_trades!(trades, account_ids, market_ids, fee_enabled?(h))
        validate_seq_uniqueness!(trades)

        true
      end

      private

      def validate_schema_version!(h)
        sv = h['schemaVersion']
        return if SUPPORTED_SCHEMA_VERSIONS.include?(sv)

        raise FCS::Error.new(
          FCS::Errors::ERR_UNSUPPORTED_SCHEMA,
          'Unsupported schemaVersion',
          details: { schemaVersion: sv, supported: SUPPORTED_SCHEMA_VERSIONS }
        )
      end

      def validate_shape!(h)
        %w[accounts markets trades priceSnapshot].each do |k|
          raise_invalid!('Missing required field', field: k) unless h.key?(k)
        end

        raise_invalid!('accounts must be an array', field: 'accounts') unless h['accounts'].is_a?(Array)
        raise_invalid!('markets must be an array', field: 'markets')   unless h['markets'].is_a?(Array)
        raise_invalid!('trades must be an array', field: 'trades')     unless h['trades'].is_a?(Array)
        raise_invalid!('priceSnapshot must be an object', field: 'priceSnapshot') unless h['priceSnapshot'].is_a?(Hash)

        timeline = h['timeline']
        return if timeline.nil?

        raise_invalid!('timeline must be an object', field: 'timeline') unless timeline.is_a?(Hash)
        return if timeline['events'].is_a?(Array)

        raise_invalid!('timeline.events must be an array',
                       field: 'timeline.events')
      end

      def validate_timeline!(h)
        timeline = h['timeline']
        return if timeline.nil?

        previous_seq = nil
        seen_full_idempotency = {}
        seen_source_external = {}
        timeline.fetch('events').each do |event|
          raise_invalid!('timeline.events item must be an object', field: 'timeline.events') unless event.is_a?(Hash)

          validate_timeline_common_fields!(event)

          idempotency_key = timeline_full_idempotency_key(event)
          source_external_key = timeline_source_external_key(event)

          if seen_full_idempotency.key?(idempotency_key)
            validate_timeline_exact_duplicate!(
              event,
              stored_event: seen_full_idempotency.fetch(idempotency_key),
              idempotency_key: idempotency_key
            )

            next
          end

          validate_timeline_partial_collision!(
            event,
            source_external_key: source_external_key,
            seen_source_external: seen_source_external
          )

          seen_full_idempotency[idempotency_key] = event
          seen_source_external[source_external_key] = event.fetch('timelineSeq')

          validate_timeline_monotonic_seq!(event.fetch('timelineSeq'), previous_seq)
          previous_seq = event.fetch('timelineSeq')

          case event.fetch('eventType')
          when 'PRICE_UPDATED'
            validate_timeline_price_updated!(event)
          when 'TRADE_APPLIED'
            validate_timeline_trade_applied!(event)
          else
            raise_invalid!('Unsupported timeline eventType',
                           field: 'timeline.events.eventType',
                           details: { eventType: event.fetch('eventType') })
          end
        end
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
            'timeline idempotency key conflict for duplicate event',
            field: 'timeline.events.idempotencyKey',
            details: {
              source: idempotency_key[0],
              externalId: idempotency_key[1],
              timelineSeq: idempotency_key[2]
            }
          )
        end

        raise_invalid!(
          'timeline duplicate event is not allowed',
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
          'timeline idempotency collision for source+externalId',
          field: 'timeline.events.externalId',
          details: {
            source: source_external_key[0],
            externalId: source_external_key[1],
            previousSeq: previous_seq,
            currentSeq: event.fetch('timelineSeq')
          }
        )
      end

      def validate_timeline_monotonic_seq!(current_seq, previous_seq)
        return if previous_seq.nil?
        return if current_seq > previous_seq

        raise_invalid!(
          'timeline timelineSeq must be strictly increasing',
          field: 'timeline.events.timelineSeq',
          details: { previousSeq: previous_seq, currentSeq: current_seq }
        )
      end

      def validate_timeline_common_fields!(event)
        unless event.key?('eventType')
          raise_invalid!('timeline eventType is required',
                         field: 'timeline.events.eventType')
        end
        unless event.key?('timelineSeq')
          raise_invalid!('timeline timelineSeq is required',
                         field: 'timeline.events.timelineSeq')
        end
        raise_invalid!('timeline source is required', field: 'timeline.events.source') unless event.key?('source')
        unless event.key?('externalId')
          raise_invalid!('timeline externalId is required',
                         field: 'timeline.events.externalId')
        end
        unless event.key?('timestamp')
          raise_invalid!('timeline timestamp is required',
                         field: 'timeline.events.timestamp')
        end

        unless non_empty_string?(event['eventType'])
          raise_invalid!('timeline eventType must be a non-empty string',
                         field: 'timeline.events.eventType')
        end
        unless event['timelineSeq'].is_a?(Integer)
          raise_invalid!('timeline timelineSeq must be an integer',
                         field: 'timeline.events.timelineSeq')
        end
        unless non_empty_string?(event['source'])
          raise_invalid!('timeline source must be a non-empty string',
                         field: 'timeline.events.source')
        end
        unless non_empty_string?(event['externalId'])
          raise_invalid!('timeline externalId must be a non-empty string',
                         field: 'timeline.events.externalId')
        end
        return if non_empty_string?(event['timestamp'])

        raise_invalid!('timeline timestamp must be a non-empty string',
                       field: 'timeline.events.timestamp')
      end

      def validate_timeline_price_updated!(event)
        unless event.key?('marketId')
          raise_invalid!('timeline PRICE_UPDATED marketId is required',
                         field: 'timeline.events.marketId')
        end
        unless event.key?('priceQuotePerBase')
          raise_invalid!('timeline PRICE_UPDATED priceQuotePerBase is required',
                         field: 'timeline.events.priceQuotePerBase')
        end

        unless non_empty_string?(event['marketId'])
          raise_invalid!('timeline PRICE_UPDATED marketId must be a non-empty string',
                         field: 'timeline.events.marketId')
        end
        validate_positive_decimal_string!(
          event['priceQuotePerBase'],
          field: 'timeline.events.priceQuotePerBase',
          context: { marketId: event['marketId'] }
        )
      end

      def validate_timeline_trade_applied!(event)
        trade = event['trade']
        unless trade.is_a?(Hash)
          raise_invalid!('timeline TRADE_APPLIED trade is required',
                         field: 'timeline.events.trade')
        end

        %w[tradeId accountId marketId seq side quantityBase priceQuotePerBase].each do |field|
          unless trade.key?(field)
            raise_invalid!("timeline TRADE_APPLIED trade.#{field} is required",
                           field: "timeline.events.trade.#{field}")
          end
        end

        unless non_empty_string?(trade['tradeId'])
          raise_invalid!('timeline.events.trade.tradeId must be a non-empty string',
                         field: 'timeline.events.trade.tradeId')
        end
        unless non_empty_string?(trade['accountId'])
          raise_invalid!('timeline.events.trade.accountId must be a non-empty string',
                         field: 'timeline.events.trade.accountId')
        end
        unless non_empty_string?(trade['marketId'])
          raise_invalid!('timeline.events.trade.marketId must be a non-empty string',
                         field: 'timeline.events.trade.marketId')
        end
        unless trade['seq'].is_a?(Integer)
          raise_invalid!('timeline.events.trade.seq must be an integer',
                         field: 'timeline.events.trade.seq')
        end
        raise_invalid!('Invalid side', field: 'timeline.events.trade.side', details: { side: trade['side'] }) unless %w[
          BUY SELL
        ].include?(trade['side'])

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

        raise_invalid!('accountingModel must be an object', field: 'accountingModel') unless model.is_a?(Hash)

        method = model['method']
        return if method.nil?

        return if SUPPORTED_ACCOUNTING_METHODS.include?(method)

        raise_invalid!(
          'Unsupported accounting method',
          field: 'accountingModel.method',
          details: { method: method, supported: SUPPORTED_ACCOUNTING_METHODS }
        )
      end

      def validate_risk_model!(h)
        model = h['riskModel']
        return if model.nil?

        raise_invalid!('riskModel must be an object', field: 'riskModel') unless model.is_a?(Hash)

        max_leverage = model['maxLeverage']
        unless max_leverage.nil?
          validate_positive_decimal_string!(max_leverage, field: 'riskModel.maxLeverage',
                                                          context: {})
        end

        maintenance = model['maintenanceMarginRatio']
        if model.key?('maintenanceMarginRatio') && maintenance.nil?
          raise_invalid!('riskModel.maintenanceMarginRatio is required when provided',
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
          raise_invalid!('riskModel.liquidation must be an object',
                         field: 'riskModel.liquidation')
        end

        enabled = liquidation['enabled']
        unless enabled.nil? || enabled == true || enabled == false
          raise_invalid!('riskModel.liquidation.enabled must be boolean', field: 'riskModel.liquidation.enabled')
        end

        close_factor = liquidation['closeFactor']
        unless liquidation.key?('closeFactor')
          raise_invalid!('riskModel.liquidation.closeFactor is required', field: 'riskModel.liquidation.closeFactor')
        end

        if liquidation.key?('closeFactor') && close_factor.nil?
          raise_invalid!('riskModel.liquidation.closeFactor is required', field: 'riskModel.liquidation.closeFactor')
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
          raise_invalid!('Missing or invalid id', field: key)
        end

        dup = ids.group_by(&:itself).find { |_k, v| v.size > 1 }&.first
        raise FCS::Error.new(code, 'Duplicate id', details: { field: key, value: dup }) if dup

        ids.to_set
      end

      def validate_snapshot!(h, market_ids)
        snap = h['priceSnapshot']
        unless non_empty_string?(snap['valuationTimestamp'])
          raise FCS::Error.new(
            FCS::Errors::ERR_MISSING_SNAPSHOT,
            'Missing snapshot valuation timestamp',
            details: { missingField: 'priceSnapshot.valuationTimestamp' }
          )
        end

        prices = snap['prices']
        unless prices.is_a?(Array)
          raise FCS::Error.new(FCS::Errors::ERR_MISSING_SNAPSHOT, 'Missing snapshot prices',
                               details: {})
        end

        price_map = {}
        seen_snapshot_markets = {}
        prices.each do |p|
          mid = p['marketId']
          unless non_empty_string?(mid)
            raise_invalid!('Missing or invalid snapshot marketId', field: 'priceSnapshot.prices.marketId')
          end

          if seen_snapshot_markets[mid]
            raise_invalid!('Duplicate snapshot marketId', field: 'priceSnapshot.prices.marketId',
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
            'Snapshot missing markets',
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
        return if fx.nil?

        unless fx.is_a?(Hash)
          raise FCS::Error.new(
            FCS::Errors::ERR_MISSING_SNAPSHOT,
            'Missing required snapshot FX payload',
            details: { missingField: 'priceSnapshot.fx.quoteUsd' }
          )
        end

        unless fx.key?('quoteUsd') && !fx['quoteUsd'].nil?
          raise FCS::Error.new(
            FCS::Errors::ERR_MISSING_SNAPSHOT,
            'Missing required snapshot FX rate',
            details: { missingField: 'priceSnapshot.fx.quoteUsd' }
          )
        end

        q = fx['quoteUsd']
        validate_positive_decimal_string!(q, field: 'priceSnapshot.fx.quoteUsd', context: {})
      end

      def validate_trades!(trades, account_ids, market_ids, fee_enabled)
        trades.each do |t|
          trade_id = t['tradeId']
          raise_invalid!('Missing tradeId', field: 'tradeId') unless non_empty_string?(trade_id)

          aid = t['accountId']
          mid = t['marketId']

          unless account_ids.include?(aid)
            raise FCS::Error.new(FCS::Errors::ERR_UNKNOWN_REFERENCE, 'Unknown accountId', details: { accountId: aid })
          end
          unless market_ids.include?(mid)
            raise FCS::Error.new(FCS::Errors::ERR_UNKNOWN_REFERENCE, 'Unknown marketId', details: { marketId: mid })
          end

          side = t['side']
          raise_invalid!('Invalid side', field: 'side', details: { side: side }) unless %w[BUY SELL].include?(side)

          validate_positive_decimal_string!(t['quantityBase'], field: 'quantityBase',
                                                               context: { tradeId: t['tradeId'] })
          validate_positive_decimal_string!(t['priceQuotePerBase'], field: 'priceQuotePerBase',
                                                                    context: { tradeId: t['tradeId'] })

          if fee_enabled && t['fee'].is_a?(Hash) && t['fee'].key?('amountQuote')
            v = t['fee']['amountQuote']
            validate_non_negative_decimal_string!(v, field: 'fee.amountQuote', context: { tradeId: t['tradeId'] })
          end

          timestamp = t['timestamp']
          unless timestamp.is_a?(Integer)
            raise_invalid!('Missing or invalid timestamp', field: 'timestamp', details: { tradeId: t['tradeId'] })
          end

          seq = t['seq']
          raise_invalid!('Missing seq', field: 'seq', details: { tradeId: t['tradeId'] }) unless seq.is_a?(Integer)
        end
      end

      def validate_seq_uniqueness!(trades)
        seen = {}
        trades.each do |t|
          key = [t['accountId'], t['marketId'], t['seq']]
          if seen[key]
            raise FCS::Error.new(
              FCS::Errors::ERR_DUPLICATE_SEQ,
              'Duplicate seq for account+market',
              details: { accountId: t['accountId'], marketId: t['marketId'], seq: t['seq'] }
            )
          end
          seen[key] = true
        end
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

        raise_invalid!("Must be <= #{max}", field: field, details: context.merge(value: v))
      end

      def validate_decimal_string!(v, field:, context:, allow_zero:)
        if v.is_a?(Float)
          raise FCS::Error.new(FCS::Errors::ERR_INVALID_NUMBER, 'Float not allowed',
                               details: context.merge(field: field))
        end

        unless v.is_a?(String) && v.match?(/\A\d+(\.\d+)?\z/)
          raise_invalid!('Invalid decimal string', field: field, details: context.merge(value: v))
        end

        parsed = FCS::Types::Decimal18.from_string(v)
        return unless !allow_zero && parsed.zero?

        raise_invalid!('Must be > 0', field: field, details: context.merge(value: v))
      end

      def non_empty_string?(v)
        v.is_a?(String) && !v.strip.empty?
      end

      def raise_invalid!(msg, field:, details: {})
        raise FCS::Error.new(FCS::Errors::ERR_VALIDATION, msg, details: details.merge(field: field))
      end
    end
  end
end
