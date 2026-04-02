class CreateReportingSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :reporting_settings do |t|
      t.string :singleton_key, null: false, default: "reporting"
      t.string :reporting_currency, null: false, default: "USD"
      t.string :updated_by_id
      t.string :updated_by_role
      t.jsonb :updated_context, null: false, default: {}
      t.timestamps
    end

    add_index :reporting_settings, :singleton_key, unique: true
  end
end
