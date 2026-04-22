class CreateDemoSandboxStates < ActiveRecord::Migration[8.1]
  def change
    create_table :demo_sandbox_states do |t|
      t.string :singleton_key, null: false, default: "demo_sandbox"
      t.datetime :last_reset_at
      t.string :last_reset_status, null: false, default: "idle"
      t.integer :last_reset_duration_ms
      t.jsonb :last_reset_result, null: false, default: {}

      t.timestamps
    end

    add_index :demo_sandbox_states, :singleton_key, unique: true
    add_index :demo_sandbox_states, :last_reset_at
  end
end
