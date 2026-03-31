class UpdateFxDailyRatesForPlaceholders < ActiveRecord::Migration[8.1]
  def change
    change_column_null :fx_daily_rates, :rate, true
    add_column :fx_daily_rates, :source_run_id, :bigint
    add_column :fx_daily_rates, :source_upload_id, :bigint

    add_index :fx_daily_rates, :source_run_id
    add_index :fx_daily_rates, :source_upload_id
  end
end
