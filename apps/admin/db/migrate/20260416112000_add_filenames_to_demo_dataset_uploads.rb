class AddFilenamesToDemoDatasetUploads < ActiveRecord::Migration[8.1]
  def change
    add_column :demo_dataset_uploads, :original_filename, :string
    add_column :demo_dataset_uploads, :normalized_filename, :string

    add_index :demo_dataset_uploads, :normalized_filename,
      unique: true,
      where: "normalized_filename IS NOT NULL",
      name: "idx_demo_dataset_uploads_normalized_filename_unique"
  end
end
