# frozen_string_literal: true

require "csv"
require "fileutils"

module FCS
  module Reporting
    # Writes positions CSV artifacts.
    #
    # @example
    #   FCS::Reporting::CsvPositions.new.write!(output_dir: "tmp/fcs", accounts: accounts)
    class CsvPositions
      HEADER = %w[
        account_id
        market_id
        quantity
        avg_cost
      ].freeze

      # @param output_dir [String]
      # @param accounts [Array<Hash>]
      # @return [String] path to positions.csv
      def write!(output_dir:, accounts:)
        FileUtils.mkdir_p(output_dir)
        path = File.join(output_dir, "positions.csv")

        CSV.open(path, "w", write_headers: true, headers: HEADER) do |csv|
          accounts.sort_by { |account| account.fetch("accountId") }.each do |acc|
            acc.fetch("markets").sort_by { |market| market.fetch("marketId") }.each do |m|
              csv << [
                acc.fetch("accountId"),
                m.fetch("marketId"),
                serialize_decimal(m.fetch("quantity")),
                serialize_decimal(m.fetch("avgCost"))
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
