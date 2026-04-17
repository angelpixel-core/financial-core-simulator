# frozen_string_literal: true

module Admin
  module DemoDataset
    module Repositories
      module ActiveRecord
        class UploadRepository
          def create_valid!(run_id:, original_filename:)
            DemoDatasetUpload.create!(status: :valid, run_id: run_id, original_filename: original_filename)
          end

          def create_invalid!(validation_errors:, original_filename:)
            DemoDatasetUpload.create!(status: :invalid, validation_errors: validation_errors,
                                      original_filename: original_filename)
          end

          def latest
            DemoDatasetUpload.latest
          end

          def delete_all!
            DemoDatasetUpload.delete_all
          end
        end
      end
    end
  end
end
