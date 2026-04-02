class CreateRunDailyPnls < ActiveRecord::Migration[8.1]
  def change
    create_table :run_daily_pnls do |t|
      t.bigint :run_snapshot_id, null: false
      t.decimal :realized_pnl, precision: 24, scale: 12, null: false
      t.decimal :unrealized_pnl, precision: 24, scale: 12, null: false
      t.decimal :total_pnl, precision: 24, scale: 12, null: false
      t.timestamps
    end

    add_index :run_daily_pnls, :run_snapshot_id, unique: true, name: "idx_run_daily_pnls_snapshot"
  end
end
