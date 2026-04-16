# frozen_string_literal: true

require 'date'

module Admin
  module Fx
    module Adapters
      class RateResolverProvider < FCS::Ports::FxProvider
        def initialize(provider: Admin::Fx::Providers::ProviderChain.new)
          @provider = provider
        end

        def fetch_rate(base_currency:, quote_currency:, at: nil)
          @provider.fetch_rate(base_currency: base_currency, quote_currency: quote_currency, at: at)
        end
      end
    end
  end
end
