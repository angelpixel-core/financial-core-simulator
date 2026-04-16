# frozen_string_literal: true

class CreateFxRateSources < ActiveRecord::Migration[8.1]
  def change
    create_table :fx_rate_sources, if_not_exists: true do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.string :source_type, null: false
      t.string :version, null: false
      t.jsonb :config, null: false, default: {}
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :fx_rate_sources, %i[code source_type version], unique: true, if_not_exists: true
  end
end
