class AddVerificationFieldsToRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :runs, :verification_status, :string
    add_column :runs, :verified_at, :datetime
    add_column :runs, :verification_input_hash, :string
    add_column :runs, :verification_error, :text

    add_index :runs, :verification_status
  end
end
