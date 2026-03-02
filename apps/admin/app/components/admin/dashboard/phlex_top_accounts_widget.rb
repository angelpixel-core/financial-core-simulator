class Admin::Dashboard::PhlexTopAccountsWidget < Phlex::HTML
  def initialize(accounts:, updated_at:)
    @accounts = accounts
    @updated_at = updated_at
  end

  def view_template
    article(class: "dashboard-card") do
      header(class: "dashboard-card__header") do
        h3 { "Top accounts (live)" }
        p(class: "dashboard-card__meta") { "Updated #{@updated_at}" }
      end

      if @accounts.empty?
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
            @accounts.each do |account|
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
end
