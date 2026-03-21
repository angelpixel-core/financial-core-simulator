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
    @accounts.map do |account|
      {
        account: account[:account_id],
        total_pnl_quote: account[:total_pnl_quote].to_s("F"),
        realized_net: account[:realized_net_pnl_quote].to_s("F"),
        unrealized: account[:unrealized_pnl_quote].to_s("F")
      }
    end
  end
end
