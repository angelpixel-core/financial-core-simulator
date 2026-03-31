class CreateRunDailyVolumes < ActiveRecord::Migration[8.1]
  def change
    create_table :run_daily_volumes do |t|
      t.bigint :run_snapshot_id, null: false
      t.decimal :notional_volume, precision: 24, scale: 12, null: false
      t.integer :trade_count, null: false, default: 0
      t.string :unit_type, null: false
      t.string :unit_code, null: false
      t.timestamps
    end

    add_index :run_daily_volumes, :run_snapshot_id, unique: true, name: 'idx_run_daily_volumes_snapshot'
  end
end
