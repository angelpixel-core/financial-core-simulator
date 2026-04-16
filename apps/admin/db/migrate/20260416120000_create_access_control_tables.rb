# frozen_string_literal: true

class CreateAccessControlTables < ActiveRecord::Migration[8.0]
  def change
    create_table :access_control_roles do |t|
      t.string :key, null: false
      t.integer :level, null: false

      t.timestamps
    end
    add_index :access_control_roles, :key, unique: true

    create_table :access_control_permissions do |t|
      t.references :access_control_role, null: false, foreign_key: true
      t.string :resource, null: false
      t.string :action, null: false

      t.timestamps
    end
    add_index :access_control_permissions, %i[access_control_role_id resource action], unique: true,
                                                                                       name: 'idx_access_control_permissions_unique'

    create_table :access_control_account_roles do |t|
      t.references :account, null: false, foreign_key: true
      t.references :access_control_role, null: false, foreign_key: true
      t.string :assigned_by_id
      t.jsonb :assigned_context, null: false, default: {}

      t.timestamps
    end
    add_index :access_control_account_roles, %i[account_id access_control_role_id], unique: true,
                                                                                    name: 'idx_access_control_account_roles_unique'

    create_table :access_control_audit_logs do |t|
      t.references :account, null: true, foreign_key: true
      t.string :action, null: false
      t.string :outcome, null: false
      t.string :role
      t.string :required_role
      t.jsonb :context, null: false, default: {}

      t.timestamps
    end
    add_index :access_control_audit_logs, :created_at
    add_index :access_control_audit_logs, %i[action outcome]
  end
end
