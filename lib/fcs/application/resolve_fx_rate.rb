# frozen_string_literal: true

module FCS
  module Application
    class ResolveFxRate
      def initialize(fx_provider: FCS::Ports::FxProvider.new)
        @fx_provider = fx_provider
      end

      def call(base_currency:, quote_currency:, operational_date:)
        @fx_provider.fetch_rate(
          base_currency: base_currency,
          quote_currency: quote_currency,
          at: operational_date
        )
      end
    end
  end
end
