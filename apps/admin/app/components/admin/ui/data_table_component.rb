class Admin::Ui::DataTableComponent < ViewComponent::Base
  def initialize(
    columns:,
    rows:,
    table_class: nil,
    state: :default,
    loading_message: "Loading dashboard data...",
    error_message: "Dashboard source unavailable.",
    empty_message: "No account totals available."
  )
    @columns = columns
    @rows = rows
    @table_class = table_class
    @state = state.to_sym
    @loading_message = loading_message
    @error_message = error_message
    @empty_message = empty_message
  end

  def loading?
    @state == :loading
  end

  def error?
    @state == :error
  end

  def empty?
    @rows.empty? && !loading? && !error?
  end

  def column_count
    [ @columns.length, 1 ].max
  end
end
