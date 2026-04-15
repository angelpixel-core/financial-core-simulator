# frozen_string_literal: true

module FCS
  module Ports
    class FxProvider
      def fetch_rate(base_currency:, quote_currency:, at: nil)
        raise NotImplementedError, "#{self.class} must implement #fetch_rate"
      end
    end
  end
end
