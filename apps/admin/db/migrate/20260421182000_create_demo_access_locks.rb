class CreateDemoAccessLocks < ActiveRecord::Migration[8.1]
  def change
    create_table :demo_access_locks do |t|
      t.string :singleton_key, null: false, default: "demo_access"
      t.string :holder_account_id
      t.string :holder_email
      t.datetime :acquired_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :demo_access_locks, :singleton_key, unique: true
    add_index :demo_access_locks, :expires_at
  end
end
