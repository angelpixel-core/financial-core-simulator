require "json"
require "bigdecimal"

module Admin
  class LiveStateMetrics
    TOP_ACCOUNTS_LIMIT = 5

    def initialize(run_scope: Run.succeeded)
      @run_scope = run_scope
    end

    def call
      run = @run_scope.order(id: :desc).first
      return nil if run.nil?

      checkpoint = latest_checkpoint(output_dir: run.output_dir)
      return nil if checkpoint.nil?

      state = checkpoint["state"]
      return nil unless state.is_a?(Hash)

      {
        checkpoint_timeline_seq: checkpoint["timelineSeq"],
        latest_global: state["global"],
        top_accounts: top_accounts_data(state["accounts"], run: run)
      }
    rescue
      nil
    end

    private

    def latest_checkpoint(output_dir:)
      return nil if output_dir.blank?

      pattern = File.join(output_dir, "checkpoint_*.json")
      path = Dir.glob(pattern).max_by { |candidate| checkpoint_seq(candidate) }
      return nil if path.nil?

      JSON.parse(File.read(path))
    rescue JSON::ParserError
      nil
    end

    def checkpoint_seq(path)
      match = File.basename(path).match(/checkpoint_(\d+)\.json\z/)
      return -1 if match.nil?

      match[1].to_i
    end

    def top_accounts_data(accounts, run:)
      source = Array(accounts)
      return nil if source.empty?

      with_totals = source.select do |account|
        account.is_a?(Hash) && account["totals"].is_a?(Hash)
      end
      return fallback_top_accounts_data(source, run: run) if with_totals.empty?

      with_totals
        .map { |account| account_metrics(account) }
        .sort_by { |entry| -entry[:total_pnl_quote] }
        .first(TOP_ACCOUNTS_LIMIT)
    end

    def fallback_top_accounts_data(accounts, run:)
      prices_by_market = snapshot_prices_by_market(run)
      return nil if prices_by_market.empty?

      realized_by_account = realized_by_account_from_events(run)

      derived = accounts.filter_map do |account|
        derived_account_metrics(
          account,
          prices_by_market: prices_by_market,
          realized_by_account: realized_by_account
        )
      end
      return nil if derived.empty?

      derived.sort_by { |entry| -entry[:total_pnl_quote] }.first(TOP_ACCOUNTS_LIMIT)
    end

    def derived_account_metrics(account, prices_by_market:, realized_by_account:)
      return nil unless account.is_a?(Hash)

      account_id = account["accountId"].to_s.strip
      return nil if account_id.empty?

      realized = realized_by_account.fetch(account_id, BigDecimal(0))

      unrealized = Array(account["markets"]).sum do |market|
        next BigDecimal(0) unless market.is_a?(Hash)

        market_id = market["marketId"].to_s.strip
        next BigDecimal(0) if market_id.empty?

        mark_price = prices_by_market[market_id]
        avg_cost = decimal_or_nil(market["avgCost"] || market["avg_cost"] || market["averageCost"])
        quantity = decimal_or_nil(market["quantity"] || market["quantityBase"] || market["positionQty"])
        next BigDecimal(0) if mark_price.nil? || avg_cost.nil? || quantity.nil?

        (mark_price - avg_cost) * quantity
      end

      total = realized + unrealized

      {
        account_id: account_id,
        total_pnl_quote: total,
        realized_net_pnl_quote: realized,
        unrealized_pnl_quote: unrealized
      }
    end

    def realized_by_account_from_events(run)
      positions = Hash.new do |accounts, account_id|
        accounts[account_id] = Hash.new do |markets, market_id|
          markets[market_id] = {
            quantity: BigDecimal(0),
            avg_cost: BigDecimal(0)
          }
        end
      end
      realized = Hash.new { |hash, account_id| hash[account_id] = BigDecimal(0) }

      persisted_trade_events_for(run).each do |trade|
        account_id = (trade["accountId"] || trade[:accountId] || trade["account_id"] || trade[:account_id]).to_s.strip
        market_id = (trade["marketId"] || trade[:marketId] || trade["market_id"] || trade[:market_id]).to_s.strip
        side = (trade["side"] || trade[:side]).to_s.upcase

        quantity = decimal_or_nil(trade["quantityBase"] || trade[:quantityBase] || trade["quantity"] || trade[:quantity])
        price = decimal_or_nil(trade["priceQuotePerBase"] || trade[:priceQuotePerBase] || trade["price"] || trade[:price])

        next if account_id.empty? || market_id.empty?
        next if quantity.nil? || price.nil?
        next if quantity <= 0
        next unless %w[BUY SELL].include?(side)

        position = positions[account_id][market_id]

        if side == "BUY"
          current_qty = position[:quantity]
          next_qty = current_qty + quantity

          if next_qty.positive?
            position[:avg_cost] = ((position[:avg_cost] * current_qty) + (price * quantity)) / next_qty
          end
          position[:quantity] = next_qty
        else
          closable_qty = [position[:quantity], quantity].min
          if closable_qty.positive?
            realized[account_id] += (price - position[:avg_cost]) * closable_qty
            position[:quantity] -= closable_qty
          end

          excess_qty = quantity - closable_qty
          if excess_qty.positive?
            position[:avg_cost] = price
            position[:quantity] -= excess_qty
          end
        end
      end

      realized
    end

    def persisted_trade_events_for(run)
      RunDailyEvent
        .joins(:run_snapshot)
        .where(run_snapshots: {run_id: run.id})
        .order("run_snapshots.operational_date ASC", "run_daily_events.event_seq ASC", "run_daily_events.id ASC")
        .filter_map do |event|
          payload = event.payload
          next unless payload.is_a?(Hash)

          event_type = payload["eventType"] || payload[:eventType] || payload["event_type"] || payload[:event_type]
          next unless event_type.to_s.upcase == "TRADE_APPLIED"

          trade = payload["trade"] || payload[:trade]
          trade if trade.is_a?(Hash)
        end
    rescue
      []
    end

    def snapshot_prices_by_market(run)
      input_json = run.input_json.is_a?(Hash) ? run.input_json : {}
      prices = input_json.dig("priceSnapshot", "prices")
      return {} unless prices.is_a?(Array)

      prices.each_with_object({}) do |entry, map|
        next unless entry.is_a?(Hash)

        market_id = entry["marketId"].to_s.strip
        next if market_id.empty?

        price = decimal_or_nil(
          entry["priceQuotePerBase"] ||
          entry["markPriceQuotePerBase"] ||
          entry["price"] ||
          entry["markPrice"]
        )
        next if price.nil?

        map[market_id] = price
      end
    end

    def account_metrics(account)
      totals = account.fetch("totals", {})
      {
        account_id: account["accountId"],
        total_pnl_quote: decimal_value(totals["totalPnLQuote"]),
        realized_net_pnl_quote: decimal_value(totals["realizedNetPnLQuote"]),
        unrealized_pnl_quote: decimal_value(totals["unrealizedPnLQuote"])
      }
    end

    def decimal_value(value)
      BigDecimal(value.to_s)
    rescue ArgumentError
      BigDecimal(0)
    end

    def decimal_or_nil(value)
      return nil if value.nil?

      BigDecimal(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
