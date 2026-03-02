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
        return if max_leverage.nil?

        validate_positive_decimal_string!(max_leverage, field: 'riskModel.maxLeverage', context: {})
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
        prices = snap['prices']
        unless prices.is_a?(Array)
          raise FCS::Error.new(FCS::Errors::ERR_MISSING_SNAPSHOT, 'Missing snapshot prices',
                               details: {})
        end

        price_map = {}
        prices.each do |p|
          mid = p['marketId']
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

        q = fx['quoteUsd']
        validate_positive_decimal_string!(q, field: 'priceSnapshot.fx.quoteUsd', context: {})
      end

      def validate_trades!(trades, account_ids, market_ids, fee_enabled)
        trades.each do |t|
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

          seq = t['seq']
          raise_invalid!('Missing seq', field: 'seq', details: { tradeId: t['tradeId'] }) unless seq.is_a?(Integer)
        end
      end

      def validate_seq_uniqueness!(trades)
        seen = {}
        trades.each do |t|
          key = "#{t['accountId']}|#{t['marketId']}|#{t['seq']}"
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

      def validate_decimal_string!(v, field:, context:, allow_zero:)
        if v.is_a?(Float)
          raise FCS::Error.new(FCS::Errors::ERR_INVALID_NUMBER, 'Float not allowed',
                               details: context.merge(field: field))
        end

        unless v.is_a?(String) && v.match?(/\A\d+(\.\d+)?\z/)
          raise_invalid!('Invalid decimal string', field: field, details: context.merge(value: v))
        end
        return unless !allow_zero && v == '0'

        raise_invalid!('Must be > 0', field: field, details: context.merge(value: v))
      end

      def raise_invalid!(msg, field:, details: {})
        raise FCS::Error.new(FCS::Errors::ERR_VALIDATION, msg, details: details.merge(field: field))
      end
    end
  end
end
