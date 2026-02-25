# frozen_string_literal: true

require "csv"
require "fileutils"

module FCS
  module Reporting
    class CsvPositions
      HEADER = %w[
        accountId
        marketId
        quantity
        avgCost
      ].freeze

      def write!(output_dir:, accounts:)
        FileUtils.mkdir_p(output_dir)
        path = File.join(output_dir, "positions.csv")

        CSV.open(path, "w", write_headers: true, headers: HEADER) do |csv|
          accounts.each do |acc|
            acc.fetch("markets").each do |m|
              csv << [
                acc.fetch("accountId"),
                m.fetch("marketId"),
                m.fetch("quantity"),
                m.fetch("avgCost")
              ]
            end
          end
        end

        path
      end
    end
  end
end
