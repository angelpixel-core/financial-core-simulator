class AddFxContextToRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :runs, :fx_context, :jsonb
  end
end
