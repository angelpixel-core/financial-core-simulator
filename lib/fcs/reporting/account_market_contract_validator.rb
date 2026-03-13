# frozen_string_literal: true

module FCS
  module Reporting
    class AccountMarketContractValidator
      REQUIRED_MARKET_FIELDS = %w[quantity avgCost realizedPnL unrealizedPnL].freeze

      def validate!(accounts:)
        accounts.each_with_index do |account, account_index|
          markets = account.fetch('markets')

          markets.each_with_index do |market, market_index|
            missing_field = REQUIRED_MARKET_FIELDS.find { |field| market[field].nil? }
            next if missing_field.nil?

            path = "accounts[#{account_index}].markets[#{market_index}].#{missing_field}"

            raise FCS::Error.new(
              FCS::Errors::ERR_VALIDATION,
              'account-market row is missing required metrics',
              details: {
                'missingField' => path,
                'accountId' => account['accountId'],
                'marketId' => market['marketId'],
                'impact' => 'Canonical account-market artifacts cannot be trusted for this run.',
                'nextAction' => 'Ensure quantity, avgCost, realizedPnL, and unrealizedPnL are present for every account-market row.'
              }
            )
          end
        end
      end
    end
  end
end
