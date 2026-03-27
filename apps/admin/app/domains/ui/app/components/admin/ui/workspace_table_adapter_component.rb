class Admin::Ui::WorkspaceTableAdapterComponent < ViewComponent::Base
  def initialize(columns:, rows:, table_class: nil, state: :default,
    loading_message: I18n.t("admin.ui.workspace_table.loading_message"),
    empty_message: I18n.t("admin.ui.workspace_table.empty_message"),
    error_message: I18n.t("admin.ui.workspace_table.error_message"))
    @columns = columns
    @rows = rows
    @table_class = table_class
    @state = state
    @loading_message = loading_message
    @empty_message = empty_message
    @error_message = error_message
  end
end
