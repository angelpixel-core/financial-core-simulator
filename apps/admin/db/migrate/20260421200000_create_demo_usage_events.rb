class CreateDemoUsageEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :demo_usage_events do |t|
      t.string :action, null: false
      t.string :status, null: false
      t.string :reason
      t.string :actor_id, null: false
      t.string :ip_address
      t.bigint :amount_bytes, null: false, default: 0
      t.jsonb :metadata, null: false, default: {}

      t.datetime :created_at, null: false
    end

    add_index :demo_usage_events, :created_at
    add_index :demo_usage_events, %i[action created_at]
    add_index :demo_usage_events, %i[action actor_id created_at], name: "idx_demo_usage_events_action_actor_created_at"
    add_index :demo_usage_events, %i[status created_at]
  end
end
