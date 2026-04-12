class Admin::Dashboard::TopAccountsTableComponent < ViewComponent::Base
  COLUMNS = [
    {key: :account, label: "Account"},
    {key: :total_pnl_quote, label: "Total PnL Quote"},
    {key: :realized_net, label: "Realized Net"},
    {key: :unrealized, label: "Unrealized"}
  ].freeze

  def initialize(accounts:)
    @accounts = accounts
  end

  def columns
    COLUMNS
  end

  def rows
    currency = reporting_currency
    @accounts.map do |account|
      {
        account: account[:account_id],
        total_pnl_quote: helpers.truncate_fiat(account[:total_pnl_quote], currency),
        realized_net: helpers.truncate_fiat(account[:realized_net_pnl_quote], currency),
        unrealized: helpers.truncate_fiat(account[:unrealized_pnl_quote], currency)
      }
    end
  end

  private

  def reporting_currency
    @reporting_currency ||= ReportingSetting.current.reporting_currency
  end
end
