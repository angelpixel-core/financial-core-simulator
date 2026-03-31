# frozen_string_literal: true

class CreateFxRateUploads < ActiveRecord::Migration[8.1]
  def change
    create_table :fx_rate_uploads do |t|
      t.string :status, null: false
      t.string :created_by_id
      t.string :created_by_role
      t.jsonb :created_context, null: false, default: {}
      t.string :original_filename
      t.string :file_path
      t.integer :error_count, null: false, default: 0
      t.text :error_message
      t.datetime :processed_at
      t.timestamps
    end

    add_index :fx_rate_uploads, :created_at
  end
end
