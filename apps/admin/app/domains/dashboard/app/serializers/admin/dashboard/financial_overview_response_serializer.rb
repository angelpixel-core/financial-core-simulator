module Admin
  module Dashboard
    class FinancialOverviewResponseSerializer
      CONTRACT_VERSION = "v1"

      def serialize(metrics:)
        payload = {
          "contractVersion" => CONTRACT_VERSION,
          "financial_overview" => {
            "trade_activity" => Array(metrics[:trade_activity]),
            "trade_volume" => Array(metrics[:trade_volume]),
            "pnlDaily" => Array(metrics[:pnl_daily])
          }
        }

        payload.deep_stringify_keys
      end
    end
  end
end
