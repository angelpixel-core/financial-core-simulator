# frozen_string_literal: true

module FCS
  module Benchmarking
    # Generates synthetic benchmark inputs.
    class InputGenerator
      def generate(trades:, accounts:, markets:)
        account_ids = (1..accounts).map { |i| "acc-#{i}" }
        market_ids = (1..markets).map { |i| "MKT-#{i}" }

        {
          "schemaVersion" => "1.0",
          "accounts" => account_ids.map { |id| {"accountId" => id} },
          "markets" => market_ids.map { |id| {"marketId" => id} },
          "feeModel" => {"enabled" => true},
          "trades" => build_trades(trades, account_ids, market_ids),
          "priceSnapshot" => build_snapshot(market_ids)
        }
      end

      private

      def build_trades(n, account_ids, market_ids)
        # Determinista y long-only safe:
        # - Alternamos BUY/SELL pero sin dejar qty negativa.
        # - Usamos qty=1 siempre para que sea simple.
        # - Fee pequeño fijo en quote.
        # - timestamp incrementa, seq = 1 siempre (ya es único por acc+market porque timestamp cambia)
        inventory = Hash.new(0) # key "acc|mkt" => qty integer
        seqs = Hash.new(0)

        out = []
        i = 0
        ts = 1

        while i < n
          acc = account_ids[i % account_ids.length]
          mkt = market_ids[(i / account_ids.length) % market_ids.length]
          key = "#{acc}|#{mkt}"

          # si no hay inventario, forzamos BUY
          side =
            if inventory[key] <= 0
              "BUY"
            else
              # alternar para dar mezcla
              (i.even? ? "SELL" : "BUY")
            end

          if side == "SELL"
            inventory[key] -= 1
            price = "101" # slightly higher
          else
            inventory[key] += 1
            price = "100"
          end

          seqs[key] += 1

          out << {
            "tradeId" => "t-#{i + 1}",
            "accountId" => acc,
            "marketId" => mkt,
            "timestamp" => ts,
            "seq" => seqs[key],
            "side" => side,
            "quantityBase" => "1",
            "priceQuotePerBase" => price,
            "fee" => {"amountQuote" => "0.01"}
          }

          i += 1
          ts += 1
        end

        out
      end

      def build_snapshot(market_ids)
        {
          "valuationTimestamp" => "2026-02-25T03:00:00Z",
          "prices" => market_ids.map { |m| {"marketId" => m, "priceQuotePerBase" => "100"} },
          "fx" => {"quoteUsd" => "1"}
        }
      end
    end
  end
end
