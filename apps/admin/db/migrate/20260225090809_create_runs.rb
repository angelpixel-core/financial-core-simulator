class CreateRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :runs do |t|
      t.integer :status
      t.string :engine_version
      t.string :schema_version
      t.string :run_uuid
      t.string :input_hash
      t.datetime :valuation_timestamp
      t.json :input_json
      t.string :output_dir
      t.json :artifacts
      t.integer :duration_ms
      t.string :error_code
      t.text :error_message

      t.timestamps
    end

    add_index :runs, :run_uuid, unique: true
    add_index :runs, :input_hash
    add_index :runs, :status
  end
end
