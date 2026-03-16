# frozen_string_literal: true

require_relative "../../lib/fcs"
require "tmpdir"
require "csv"

RSpec.describe FCS::Reporting::CsvPositions do
  it "writes sorted positions csv" do
    accounts = [
      {
        "accountId" => "b",
        "markets" => [
          { "marketId" => "m-2", "quantity" => "1", "avgCost" => "100" },
          { "marketId" => "m-1", "quantity" => "2", "avgCost" => "110" }
        ]
      },
      {
        "accountId" => "a",
        "markets" => [
          { "marketId" => "m-1", "quantity" => "3", "avgCost" => "120" }
        ]
      }
    ]

    Dir.mktmpdir do |dir|
      path = described_class.new.write!(output_dir: dir, accounts: accounts)
      rows = CSV.read(path, headers: true)

      expect(rows.map { |r| [r["account_id"], r["market_id"]] }).to eq(
        [%w[a m-1], %w[b m-1], %w[b m-2]]
      )
    end
  end
end
