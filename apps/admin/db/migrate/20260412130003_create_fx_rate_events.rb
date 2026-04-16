# frozen_string_literal: true

class CreateFxRateEvents < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :fx_rate_events, if_not_exists: true do |t|
      t.uuid :event_id, null: false, default: -> { "gen_random_uuid()" }
      t.string :event_type, null: false
      t.jsonb :data, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :fx_rate_events, :event_id, unique: true, if_not_exists: true
    add_index :fx_rate_events, :event_type, if_not_exists: true
    add_index :fx_rate_events, :metadata, using: :gin, if_not_exists: true
  end
end
