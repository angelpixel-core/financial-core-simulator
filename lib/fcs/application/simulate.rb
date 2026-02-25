# frozen_string_literal: true

module FCS
  module Application
    class Simulate
      def call(input)
        fx = FCS::Engine::FXConverter.new(price_snapshot: input.fetch("priceSnapshot"))

        fee_enabled = input.dig("feeModel", "enabled")
        ledger = FCS::Engine::LedgerEngine.new(fee_enabled: fee_enabled)
        input.fetch("trades").each { |t| ledger.apply_trade!(t) }

        valuation = FCS::Engine::ValuationEngine.new(price_snapshot: input.fetch("priceSnapshot"))

        accounts = build_accounts(input, ledger.state, valuation, fx)
        global = consolidate_global(accounts, fx)

        { "accounts" => accounts, "global" => global }
      end

      private

      def build_accounts(input, state, valuation, fx)
        account_ids = input.fetch("accounts").map { |a| a.fetch("accountId") }
        market_ids = input.fetch("markets").map { |m| m.fetch("marketId") }

        account_ids.map do |account_id|
          markets = market_ids.map do |market_id|
            pos = state.position_for(account_id: account_id, market_id: market_id)

            unreal = valuation.unrealized_pnl_quote(market_id: market_id, position: pos)
            realized = pos.realized_pnl_quote
            fees = pos.fees_quote
            realized_net = pos.realized_net_quote
            total = realized_net + unreal

            {
              "marketId" => market_id,
              "quantity" => pos.qty.to_s,
              "avgCost" => pos.avg_cost.to_s,
              "realizedPnLQuote" => realized.to_s,
              "feesQuote" => fees.to_s,
              "realizedNetPnLQuote" => realized_net.to_s,
              "unrealizedPnLQuote" => unreal.to_s,
              "totalPnLQuote" => total.to_s
            }
          end

          totals = sum_market_fields(markets, fx)

          {
            "accountId" => account_id,
            "markets" => markets,
            "totals" => totals
          }
        end
      end

      def sum_market_fields(markets, fx)
        z = FCS::Types::Decimal18.new(0)
        realized = z
        fees = z
        realized_net = z
        unreal = z
        total = z

        markets.each do |m|
          realized += FCS::Types::Decimal18.from_string(m["realizedPnLQuote"])
          fees += FCS::Types::Decimal18.from_string(m["feesQuote"])
          realized_net += FCS::Types::Decimal18.from_string(m["realizedNetPnLQuote"])
          unreal += FCS::Types::Decimal18.from_string(m["unrealizedPnLQuote"])
          total += FCS::Types::Decimal18.from_string(m["totalPnLQuote"])
        end

        {
          "realizedPnLQuote" => realized.to_s,
          "feesQuote" => fees.to_s,
          "realizedNetPnLQuote" => realized_net.to_s,
          "unrealizedPnLQuote" => unreal.to_s,
          "totalPnLQuote" => total.to_s,
          "totalPnLUsd" => fx.enabled? ? fx.quote_to_usd(total).to_s : nil
        }
      end

      def consolidate_global(accounts, fx)
        z = FCS::Types::Decimal18.new(0)
        realized = z
        fees = z
        realized_net = z
        unreal = z
        total = z

        accounts.each do |a|
          t = a.fetch("totals")
          realized += FCS::Types::Decimal18.from_string(t["realizedPnLQuote"])
          fees += FCS::Types::Decimal18.from_string(t["feesQuote"])
          realized_net += FCS::Types::Decimal18.from_string(t["realizedNetPnLQuote"])
          unreal += FCS::Types::Decimal18.from_string(t["unrealizedPnLQuote"])
          total += FCS::Types::Decimal18.from_string(t["totalPnLQuote"])
        end

        {
          "realizedPnLQuote" => realized.to_s,
          "feesQuote" => fees.to_s,
          "realizedNetPnLQuote" => realized_net.to_s,
          "unrealizedPnLQuote" => unreal.to_s,
          "totalPnLQuote" => total.to_s,
          "totalPnLUsd" => fx.enabled? ? fx.quote_to_usd(total).to_s : nil
        }
      end
    end
  end
end
