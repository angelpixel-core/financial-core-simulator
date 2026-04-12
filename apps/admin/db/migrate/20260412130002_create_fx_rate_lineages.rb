# frozen_string_literal: true

class CreateFxRateLineages < ActiveRecord::Migration[8.1]
  def change
    create_table :fx_rate_lineages do |t|
      t.references :ingestion, null: false, foreign_key: {to_table: :fx_rate_ingestions}
      t.references :source, null: false, foreign_key: {to_table: :fx_rate_sources}
      t.date :operational_date, null: false
      t.string :base_currency, null: false
      t.string :quote_currency, null: false
      t.jsonb :raw_payload, null: false, default: {}
      t.jsonb :normalized_payload, null: false, default: {}
      t.string :status, null: false
      t.string :error_code
      t.jsonb :context, null: false, default: {}
      t.string :correlation_id, null: false
      t.string :causation_id

      t.timestamps
    end

    add_index :fx_rate_lineages, %i[ingestion_id operational_date]
    add_index :fx_rate_lineages, %i[base_currency quote_currency]
    add_index :fx_rate_lineages, :correlation_id
  end
end
