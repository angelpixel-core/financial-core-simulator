# frozen_string_literal: true

require 'csv'
require 'fileutils'

module FCS
  module Reporting
    class CsvPnL
      HEADER = %w[
        accountId
        marketId
        realizedPnLQuote
        feesQuote
        realizedNetPnLQuote
        unrealizedPnLQuote
        totalPnLQuote
        totalPnLUsd
      ].freeze

      def write!(output_dir:, accounts:)
        FileUtils.mkdir_p(output_dir)
        path = File.join(output_dir, 'pnl.csv')

        CSV.open(path, 'w', write_headers: true, headers: HEADER) do |csv|
          accounts.sort_by { |account| account.fetch('accountId') }.each do |acc|
            acc.fetch('markets').sort_by { |market| market.fetch('marketId') }.each do |m|
              csv << [
                acc.fetch('accountId'),
                m.fetch('marketId'),
                m.fetch('realizedPnLQuote'),
                m.fetch('feesQuote'),
                m.fetch('realizedNetPnLQuote'),
                m.fetch('unrealizedPnLQuote'),
                m.fetch('totalPnLQuote'),
                m['totalPnLUsd']
              ]
            end
          end
        end

        path
      end
    end
  end
end
