require "bigdecimal"

class Admin::Dashboard::PhlexTopAccountsWidget < Phlex::HTML
  def initialize(accounts:, updated_at:, drilldown_path: nil, drilldown_label: nil)
    @accounts = Array(accounts)
    @updated_at = updated_at
    @drilldown_path = drilldown_path
    @drilldown_label = drilldown_label
  end

  def view_template
    article(class: "dashboard-card") do
      header(class: "dashboard-card__header") do
        h3 { "Top accounts (live)" }
        div(class: "dashboard-card__meta-actions") do
          p(class: "dashboard-card__meta") { "Updated #{@updated_at}" }
          if @drilldown_path.present?
            a(href: @drilldown_path, class: "overview__link") { @drilldown_label || "View details" }
          end
        end
      end

      accounts = sorted_accounts

      if accounts.empty?
        p(class: "empty-state") { "No account totals available." }
      else
        table(class: "top-accounts-table") do
          thead do
            tr do
              th { "Account" }
              th { "Total PnL Quote" }
              th { "Realized Net" }
              th { "Unrealized" }
            end
          end
          tbody do
            accounts.each do |account|
              tr do
                td { account[:account_id] }
                td { account[:total_pnl_quote].to_s("F") }
                td { account[:realized_net_pnl_quote].to_s("F") }
                td { account[:unrealized_pnl_quote].to_s("F") }
              end
            end
          end
        end
      end
    end
  end

  private

  def sorted_accounts
    @accounts.sort_by { |account| -decimal_value(account[:total_pnl_quote]) }
  end

  def decimal_value(value)
    BigDecimal(value.to_s)
  rescue ArgumentError
    BigDecimal("0")
  end
end
