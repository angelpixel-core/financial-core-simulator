# frozen_string_literal: true

module FCS
  module Engine
    # Converts quote currency values to USD when enabled.
    class FXConverter
      def initialize(price_snapshot:, usd_enabled:)
        @usd_enabled = usd_enabled
        fx = price_snapshot["fx"]
        @quote_usd =
          (FCS::Types::Decimal18.from_string(fx.fetch("quoteUsd")) if fx && fx["quoteUsd"])

        raise_missing_fx_for_usd_enabled! if @usd_enabled && @quote_usd.nil?
      end

      def enabled?
        @usd_enabled && !@quote_usd.nil?
      end

      def quote_to_usd(amount_quote)
        raise_missing_fx_for_usd_enabled! unless enabled?

        amount_quote * @quote_usd
      end

      private

      def raise_missing_fx_for_usd_enabled!
        raise FCS::Error.new(
          FCS::Errors::ERR_MISSING_SNAPSHOT,
          "Missing required snapshot FX rate",
          details: {
            missingField: "priceSnapshot.fx.quoteUsd",
            what_happened: "USD conversion is enabled but quoteUsd FX rate is missing from snapshot.",
            impact: "Account and global USD totals cannot be calculated deterministically.",
            next_action: "Provide priceSnapshot.fx.quoteUsd as a positive decimal string, or disable usdModel.enabled."
          }
        )
      end
    end
  end
end
