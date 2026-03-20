class Admin::Ui::WorkspaceTableAdapterComponent < ViewComponent::Base
  def initialize(columns:, rows:, table_class: nil, state: :default, loading_message: "Loading workspace table...",
    empty_message: "No rows available.", error_message: "Workspace table unavailable.")
    @columns = columns
    @rows = rows
    @table_class = table_class
    @state = state
    @loading_message = loading_message
    @empty_message = empty_message
    @error_message = error_message
  end
end
