# frozen_string_literal: true

class CreateFxRateIngestions < ActiveRecord::Migration[8.1]
  def change
    create_table :fx_rate_ingestions do |t|
      t.references :source, null: false, foreign_key: {to_table: :fx_rate_sources}
      t.string :status, null: false
      t.string :error_code
      t.jsonb :context, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.string :correlation_id, null: false
      t.string :causation_id
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :fx_rate_ingestions, :correlation_id
    add_index :fx_rate_ingestions, :status
  end
end
