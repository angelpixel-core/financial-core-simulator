# frozen_string_literal: true

module FCS
  module Engine
    # Tracks positions and balances per account and market.
    class LedgerState
      def initialize(dependencies: Dependencies.default, position_builder: nil)
        position_builder ||= -> { Position.empty(dependencies: dependencies) }
        @positions = {} # key: "accountId|marketId" => Position
        @position_builder = position_builder
      end

      def position_for(account_id:, market_id:)
        key = key_for(account_id, market_id)
        @positions[key] ||= @position_builder.call
      end

      attr_reader :positions

      private

      def key_for(account_id, market_id)
        "#{account_id}|#{market_id}"
      end
    end
  end
end
