class Admin::Ui::DataTableComponentPreview < ViewComponent::Preview
  def default
    render Admin::Ui::DataTableComponent.new(
      columns: columns,
      rows: [
        {
          account: "acc-1",
          total_pnl_quote: "125.50",
          realized_net: "100.00",
          unrealized: "25.50"
        },
        {
          account: "acc-2",
          total_pnl_quote: "-20.00",
          realized_net: "-10.00",
          unrealized: "-10.00"
        }
      ]
    )
  end

  def loading
    render Admin::Ui::DataTableComponent.new(
      columns: columns,
      rows: [
        {
          account: "loading...",
          total_pnl_quote: "...",
          realized_net: "...",
          unrealized: "..."
        }
      ]
    )
  end

  def empty
    render Admin::Ui::DataTableComponent.new(
      columns: columns,
      rows: []
    )
  end

  def error
    render Admin::Ui::DataTableComponent.new(
      columns: columns,
      rows: [
        {
          account: "error",
          total_pnl_quote: "-",
          realized_net: "Data source unavailable",
          unrealized: "-"
        }
      ]
    )
  end

  private

  def columns
    [
      { key: :account, label: "Account" },
      { key: :total_pnl_quote, label: "Total PnL Quote" },
      { key: :realized_net, label: "Realized Net" },
      { key: :unrealized, label: "Unrealized" }
    ]
  end
end
