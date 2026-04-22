class CreateDemoRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :demo_requests do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :company, null: false
      t.string :preferred_contact, null: false, default: "video_call"
      t.text :message
      t.string :status, null: false, default: "pending"

      t.timestamps null: false
    end

    add_index :demo_requests, :created_at
    add_index :demo_requests, :email
    add_index :demo_requests, :status
  end
end
