class CreateFxRateGaps < ActiveRecord::Migration[8.1]
  def change
    create_table :fx_rate_gaps do |t|
      t.date :operational_date, null: false
      t.string :base_currency, null: false
      t.string :quote_currency, null: false
      t.string :status, null: false
      t.bigint :placeholder_rate_id
      t.bigint :resolved_rate_id
      t.bigint :source_run_id
      t.bigint :source_upload_id
      t.datetime :resolved_at
      t.datetime :ignored_at
      t.jsonb :created_context, null: false, default: {}
      t.timestamps
    end

    add_index :fx_rate_gaps,
              %i[operational_date base_currency quote_currency],
              unique: true,
              where: "status = 'open'",
              name: 'idx_fx_rate_gaps_open'
    add_index :fx_rate_gaps, :placeholder_rate_id
    add_index :fx_rate_gaps, :resolved_rate_id
    add_index :fx_rate_gaps, :source_run_id
    add_index :fx_rate_gaps, :source_upload_id
  end
end
