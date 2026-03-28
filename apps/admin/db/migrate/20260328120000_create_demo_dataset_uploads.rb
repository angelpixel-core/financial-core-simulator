class CreateDemoDatasetUploads < ActiveRecord::Migration[8.1]
  def change
    create_table :demo_dataset_uploads do |t|
      t.string :status, null: false
      t.jsonb :validation_errors, default: [], null: false
      t.bigint :run_id

      t.timestamps
    end

    add_index :demo_dataset_uploads, :run_id
    add_index :demo_dataset_uploads, :created_at
  end
end
