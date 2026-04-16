# frozen_string_literal: true

class AddSourceToFxDailyRates < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:fx_daily_rates, :source_id)
      add_reference :fx_daily_rates, :source, foreign_key: {to_table: :fx_rate_sources}
    end
    add_index :fx_daily_rates, %i[operational_date base_currency quote_currency source_id],
      unique: true, name: "index_fx_daily_rates_on_date_currency_source", if_not_exists: true
  end
end
