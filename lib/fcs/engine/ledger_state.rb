# frozen_string_literal: true

module FCS
  module Engine
    # Tracks positions and balances per account and market.
    #
    # @example
    #   state = FCS::Engine::LedgerState.new
    #   state.position_for(account_id: "acc-1", market_id: "btc-usd")
    class LedgerState
      # @param dependencies [FCS::Engine::Dependencies]
      # @param position_builder [Proc, nil]
      def initialize(dependencies: Dependencies.default, position_builder: nil)
        position_builder ||= -> { Position.empty(dependencies: dependencies) }
        @positions = {} # key: "accountId|marketId" => Position
        @position_builder = position_builder
      end

      # Returns the position for an account/market, creating it if absent.
      #
      # @param account_id [String]
      # @param market_id [String]
      # @return [FCS::Engine::Position, FCS::Engine::PositionFifo]
      def position_for(account_id:, market_id:)
        key = key_for(account_id, market_id)
        @positions[key] ||= @position_builder.call
      end

      # Returns the internal positions hash.
      #
      # @return [Hash]
      attr_reader :positions

      private

      def key_for(account_id, market_id)
        "#{account_id}|#{market_id}"
      end
    end
  end
end
