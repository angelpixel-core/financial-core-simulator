require 'json'
require 'bigdecimal'

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

      state = checkpoint['state']
      return nil unless state.is_a?(Hash)

      {
        checkpoint_timeline_seq: checkpoint['timelineSeq'],
        latest_global: state['global'],
        top_accounts: top_accounts_data(state['accounts'], run: run)
      }
    rescue StandardError
      nil
    end

    private

    def latest_checkpoint(output_dir:)
      return nil if output_dir.blank?

      pattern = File.join(output_dir, 'checkpoint_*.json')
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
        account.is_a?(Hash) && account['totals'].is_a?(Hash)
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

      derived = accounts.filter_map { |account| derived_account_metrics(account, prices_by_market: prices_by_market) }
      return nil if derived.empty?

      derived.sort_by { |entry| -entry[:total_pnl_quote] }.first(TOP_ACCOUNTS_LIMIT)
    end

    def derived_account_metrics(account, prices_by_market:)
      return nil unless account.is_a?(Hash)

      account_id = account['accountId'].to_s.strip
      return nil if account_id.empty?

      unrealized = Array(account['markets']).sum do |market|
        next BigDecimal(0) unless market.is_a?(Hash)

        market_id = market['marketId'].to_s.strip
        next BigDecimal(0) if market_id.empty?

        mark_price = prices_by_market[market_id]
        avg_cost = decimal_or_nil(market['avgCost'] || market['avg_cost'] || market['averageCost'])
        quantity = decimal_or_nil(market['quantity'] || market['quantityBase'] || market['positionQty'])
        next BigDecimal(0) if mark_price.nil? || avg_cost.nil? || quantity.nil?

        (mark_price - avg_cost) * quantity
      end

      {
        account_id: account_id,
        total_pnl_quote: unrealized,
        realized_net_pnl_quote: BigDecimal(0),
        unrealized_pnl_quote: unrealized
      }
    end

    def snapshot_prices_by_market(run)
      input_json = run.input_json.is_a?(Hash) ? run.input_json : {}
      prices = input_json.dig('priceSnapshot', 'prices')
      return {} unless prices.is_a?(Array)

      prices.each_with_object({}) do |entry, map|
        next unless entry.is_a?(Hash)

        market_id = entry['marketId'].to_s.strip
        next if market_id.empty?

        price = decimal_or_nil(
          entry['priceQuotePerBase'] ||
          entry['markPriceQuotePerBase'] ||
          entry['price'] ||
          entry['markPrice']
        )
        next if price.nil?

        map[market_id] = price
      end
    end

    def account_metrics(account)
      totals = account.fetch('totals', {})
      {
        account_id: account['accountId'],
        total_pnl_quote: decimal_value(totals['totalPnLQuote']),
        realized_net_pnl_quote: decimal_value(totals['realizedNetPnLQuote']),
        unrealized_pnl_quote: decimal_value(totals['unrealizedPnLQuote'])
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
