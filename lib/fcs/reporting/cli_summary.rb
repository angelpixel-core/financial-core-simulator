# frozen_string_literal: true

module FCS
  module Reporting
    class CliSummary
      def print(result_json_payload)
        puts
        puts "=== FCS Summary ==="

        puts "Engine: #{result_json_payload.fetch("engineVersion")}"
        puts "Schema: #{result_json_payload.fetch("schemaVersion")}"
        puts "Run: #{result_json_payload.fetch("runId")}"
        puts "Valuation: #{result_json_payload.fetch("valuationTimestamp")}"
        puts "InputHash: #{result_json_payload.fetch("inputHash")}"

        puts
        print_global(result_json_payload.fetch("global"))

        puts
        print_accounts(result_json_payload.fetch("accounts"))
        puts
      end

      private

      def print_global(g)
        puts "-- Global --"
        puts "Realized (quote):     #{g.fetch("realizedPnLQuote")}"
        puts "Fees (quote):         #{g.fetch("feesQuote")}"
        puts "Realized Net (quote): #{g.fetch("realizedNetPnLQuote")}"
        puts "Unrealized (quote):   #{g.fetch("unrealizedPnLQuote")}"
        puts "Total (quote):        #{g.fetch("totalPnLQuote")}"

        usd = g["totalPnLUsd"]
        puts "Total (USD):          #{usd.nil? ? "n/a" : usd}"
      end

      def print_accounts(accounts)
        puts "-- Accounts --"
        accounts.each do |a|
          t = a.fetch("totals")
          line = "• #{a.fetch("accountId")}: totalQuote=#{t.fetch("totalPnLQuote")}"
          line += " totalUsd=#{t["totalPnLUsd"]}" if t["totalPnLUsd"]
          puts line
        end
      end
    end
  end
end
