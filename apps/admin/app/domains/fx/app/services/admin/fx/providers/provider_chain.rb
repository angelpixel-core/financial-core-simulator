# frozen_string_literal: true

module Admin
  module Fx
    module Providers
      class ProviderChain < FCS::Ports::FxProvider
        def initialize(providers: [
          Admin::Fx::Providers::ManualAdapter.new,
          Admin::Fx::Providers::BcraAdapter.new
        ])
          @providers = providers
        end

        def fetch_rate(base_currency:, quote_currency:, at: nil)
          fallback = nil

          @providers.each do |provider|
            result = provider.fetch_rate(base_currency: base_currency, quote_currency: quote_currency, at: at)
            return result unless result[:rate_missing]

            fallback = result
          end

          fallback || {
            rate: nil,
            rate_source: 'provider_chain_empty',
            rate_missing: true,
            operational_date: at
          }
        end
      end
    end
  end
end
