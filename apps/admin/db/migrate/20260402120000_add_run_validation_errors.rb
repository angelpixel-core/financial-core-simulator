class AddRunValidationErrors < ActiveRecord::Migration[8.1]
  def change
    add_column :runs, :reliable, :boolean, null: false, default: true

    create_table :run_validation_errors do |t|
      t.bigint :run_id, null: false
      t.string :source
      t.string :field
      t.text :message, null: false, default: ""
      t.string :code
      t.string :trade_id
      t.string :account_id
      t.string :market_id
      t.integer :timeline_seq
      t.string :event_type
      t.integer :row_index
      t.datetime :occurred_at
      t.string :correlation_id

      t.timestamps
    end

    add_index :run_validation_errors, :run_id
    add_index :run_validation_errors, :created_at
  end
end
