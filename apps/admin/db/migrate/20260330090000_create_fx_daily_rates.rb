class CreateFxDailyRates < ActiveRecord::Migration[8.1]
  def change
    create_table :fx_daily_rates do |t|
      t.date :operational_date, null: false
      t.string :base_currency, null: false
      t.string :quote_currency, null: false
      t.decimal :rate, precision: 24, scale: 12, null: false
      t.string :source, null: false
      t.bigint :source_rate_id
      t.string :created_by_id
      t.string :created_by_role
      t.jsonb :created_context, null: false, default: {}
      t.timestamps
    end

    add_index :fx_daily_rates,
      %i[operational_date base_currency quote_currency],
      unique: true,
      name: "idx_fx_daily_rates_unique"
    add_index :fx_daily_rates, :source_rate_id
  end
end
