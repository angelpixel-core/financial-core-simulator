class CreateRunDailyEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :run_daily_events do |t|
      t.bigint :run_snapshot_id, null: false
      t.string :event_type, null: false
      t.integer :event_seq
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end

    add_index :run_daily_events, %i[run_snapshot_id event_seq], unique: true
  end
end
