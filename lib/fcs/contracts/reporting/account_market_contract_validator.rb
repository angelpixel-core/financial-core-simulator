# frozen_string_literal: true

module FCS
  module Contracts
    module Reporting
      class AccountMarketContractValidator
        REQUIRED_MARKET_FIELDS = %w[quantity avgCost realizedPnL unrealizedPnL].freeze

        def validate!(accounts:)
          accounts.each_with_index do |account, account_index|
            markets = account.fetch('markets')

            markets.each_with_index do |market, market_index|
              REQUIRED_MARKET_FIELDS.each do |field|
                validate_metric_field!(
                  account: account,
                  account_index: account_index,
                  market: market,
                  market_index: market_index,
                  field: field
                )
              end
            end
          end
        end

        private

        def validate_metric_field!(account:, account_index:, market:, market_index:, field:)
          value = market[field]
          path = "accounts[#{account_index}].markets[#{market_index}].#{field}"

          if value.nil?
            raise_contract_error!(
              message: t('fcs.reporting.account_market.missing_required_metrics'),
              missing_field: path,
              account_id: account['accountId'],
              market_id: market['marketId']
            )
          end

          if value.is_a?(String) && value.strip.empty?
            raise_contract_error!(
              message: t('fcs.reporting.account_market.empty_required_metrics'),
              missing_field: path,
              account_id: account['accountId'],
              market_id: market['marketId'],
              invalid_value: value
            )
          end

          begin
            FCS::Types::Decimal18.from_string(value.to_s)
          rescue StandardError
            raise_contract_error!(
              message: t('fcs.reporting.account_market.invalid_metric_format'),
              missing_field: path,
              account_id: account['accountId'],
              market_id: market['marketId'],
              invalid_value: value
            )
          end
        end

        def raise_contract_error!(message:, missing_field:, account_id:, market_id:, invalid_value: nil)
          details = {
            'missing_field' => missing_field,
            'account_id' => account_id,
            'market_id' => market_id,
            'impact' => t('fcs.reporting.account_market.impact'),
            'next_action' => t('fcs.reporting.account_market.next_action')
          }
          details['invalid_value'] = invalid_value unless invalid_value.nil?

          raise FCS::Error.new(
            FCS::Errors::ERR_VALIDATION,
            message,
            details: details
          )
        end

        def t(key, **opts)
          ::I18n.t(key, **opts)
        end
      end
    end
  end
end
