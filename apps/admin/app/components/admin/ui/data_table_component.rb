class Admin::Ui::DataTableComponent < ViewComponent::Base
  def initialize(columns:, rows:, table_class: nil)
    @columns = columns
    @rows = rows
    @table_class = table_class
  end
end
