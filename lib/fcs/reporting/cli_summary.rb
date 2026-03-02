# frozen_string_literal: true

module FCS
  module Reporting
    class CliSummary
      def initialize(io: $stdout)
        @io = io
      end

      def print(result_json_payload)
        @io.puts
        @io.puts '=== FCS Summary ==='

        @io.puts "Engine: #{result_json_payload.fetch('engineVersion')}"
        @io.puts "Schema: #{result_json_payload.fetch('schemaVersion')}"
        @io.puts "Run: #{result_json_payload.fetch('runId')}"
        @io.puts "Valuation: #{result_json_payload.fetch('valuationTimestamp')}"
        @io.puts "InputHash: #{result_json_payload.fetch('inputHash')}"

        @io.puts
        print_global(result_json_payload.fetch('global'))

        @io.puts
        print_accounts(result_json_payload.fetch('accounts'))
        @io.puts
      end

      private

      def print_global(g)
        @io.puts '-- Global --'
        @io.puts "Realized (quote):     #{g.fetch('realizedPnLQuote')}"
        @io.puts "Fees (quote):         #{g.fetch('feesQuote')}"
        @io.puts "Realized Net (quote): #{g.fetch('realizedNetPnLQuote')}"
        @io.puts "Unrealized (quote):   #{g.fetch('unrealizedPnLQuote')}"
        @io.puts "Total (quote):        #{g.fetch('totalPnLQuote')}"

        usd = g['totalPnLUsd']
        @io.puts "Total (USD):          #{usd.nil? ? 'n/a' : usd}"
      end

      def print_accounts(accounts)
        @io.puts '-- Accounts --'
        accounts.each do |a|
          t = a.fetch('totals')
          line = "• #{a.fetch('accountId')}: totalQuote=#{t.fetch('totalPnLQuote')}"
          line += " totalUsd=#{t['totalPnLUsd']}" if t['totalPnLUsd']
          @io.puts line
        end
      end
    end
  end
end
