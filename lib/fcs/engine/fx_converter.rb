# frozen_string_literal: true

module FCS
  module Engine
    class FXConverter
      def initialize(price_snapshot:, usd_enabled:)
        @usd_enabled = usd_enabled
        fx = price_snapshot['fx']
        @quote_usd =
          (FCS::Types::Decimal18.from_string(fx.fetch('quoteUsd')) if fx && fx['quoteUsd'])
      end

      def enabled?
        @usd_enabled && !@quote_usd.nil?
      end

      def quote_to_usd(amount_quote)
        raise 'FX not enabled' unless enabled?

        amount_quote * @quote_usd
      end
    end
  end
end
