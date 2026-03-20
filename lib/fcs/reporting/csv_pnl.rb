# frozen_string_literal: true

require "csv"
require "fileutils"

module FCS
  module Reporting
    # Writes PnL CSV artifacts.
    #
    # @example
    #   FCS::Reporting::CsvPnL.new.write!(output_dir: "tmp/fcs", accounts: accounts)
    class CsvPnL
      HEADER = %w[
        account_id
        market_id
        realized_pnl_quote
        fees_quote
        realized_net_pnl_quote
        unrealized_pnl_quote
        total_pnl_quote
        total_pnl_usd
      ].freeze

      # @param output_dir [String]
      # @param accounts [Array<Hash>]
      # @return [String] path to pnl.csv
      def write!(output_dir:, accounts:)
        FileUtils.mkdir_p(output_dir)
        path = File.join(output_dir, "pnl.csv")

        CSV.open(path, "w", write_headers: true, headers: HEADER) do |csv|
          accounts.sort_by { |account| account.fetch("accountId") }.each do |acc|
            acc.fetch("markets").sort_by { |market| market.fetch("marketId") }.each do |m|
              csv << [
                acc.fetch("accountId"),
                m.fetch("marketId"),
                serialize_decimal(m.fetch("realizedPnLQuote")),
                serialize_decimal(m.fetch("feesQuote")),
                serialize_decimal(m.fetch("realizedNetPnLQuote")),
                serialize_decimal(m.fetch("unrealizedPnLQuote")),
                serialize_decimal(m.fetch("totalPnLQuote")),
                serialize_decimal(m["totalPnLUsd"])
              ]
            end
          end
        end

        path
      end

      private

      def serialize_decimal(value)
        return nil if value.nil?

        FCS::Types::Decimal18.from_string(value.to_s).to_s
      end
    end
  end
end
