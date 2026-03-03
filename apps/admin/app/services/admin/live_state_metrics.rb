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
        top_accounts: top_accounts_data(state["accounts"])
      }
    rescue StandardError
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

    def top_accounts_data(accounts)
      Array(accounts)
        .map { |account| account_metrics(account) }
        .sort_by { |entry| -entry[:total_pnl_quote] }
        .first(TOP_ACCOUNTS_LIMIT)
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
      BigDecimal("0")
    end
  end
end
