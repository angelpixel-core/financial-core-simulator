# frozen_string_literal: true

module FCS
  module Engine
    class LedgerState
      def initialize(position_builder: -> { Position.empty })
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
