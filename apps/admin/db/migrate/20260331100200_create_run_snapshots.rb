class CreateRunSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :run_snapshots do |t|
      t.bigint :run_id, null: false
      t.date :operational_date, null: false
      t.string :reporting_currency, null: false
      t.timestamps
    end

    add_index :run_snapshots,
              %i[run_id operational_date reporting_currency],
              unique: true,
              name: 'idx_run_snapshots_unique'
  end
end
