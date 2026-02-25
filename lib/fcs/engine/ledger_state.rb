# frozen_string_literal: true

module FCS
  module Engine
    class LedgerState
      def initialize
        @positions = {} # key: "accountId|marketId" => Position
      end

      def position_for(account_id:, market_id:)
        key = key_for(account_id, market_id)
        @positions[key] ||= Position.empty
      end

      def positions
        @positions
      end

      private

      def key_for(account_id, market_id)
        "#{account_id}|#{market_id}"
      end
    end
  end
end
