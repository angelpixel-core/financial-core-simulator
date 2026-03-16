# frozen_string_literal: true

require_relative "../../lib/fcs"
require "tmpdir"
require "csv"

RSpec.describe FCS::Reporting::CsvPnL do
  it "writes pnl csv with totals" do
    accounts = [
      {
        "accountId" => "a",
        "markets" => [
          {
            "marketId" => "m-1",
            "realizedPnLQuote" => "1",
            "feesQuote" => "0.5",
            "realizedNetPnLQuote" => "0.5",
            "unrealizedPnLQuote" => "2",
            "totalPnLQuote" => "2.5",
            "totalPnLUsd" => nil
          }
        ]
      }
    ]

    Dir.mktmpdir do |dir|
      path = described_class.new.write!(output_dir: dir, accounts: accounts)
      rows = CSV.read(path, headers: true)

      expect(rows.first.to_h).to include(
        "account_id" => "a",
        "market_id" => "m-1",
        "realized_pnl_quote" => "1.0",
        "total_pnl_quote" => "2.5"
      )
    end
  end
end
