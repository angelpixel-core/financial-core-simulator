# frozen_string_literal: true

module Admin
  module Fx
    module Repositories
      module ActiveRecord
        class RateUploadRepository
          def create_processing!(created_by_id:, created_by_role:, created_context:, original_filename:)
            FxRateUpload.create!(
              status: "processing",
              created_by_id: created_by_id,
              created_by_role: created_by_role,
              created_context: created_context,
              original_filename: original_filename
            )
          end

          def find(upload_id)
            FxRateUpload.find(upload_id)
          end

          def find_by_id(upload_id)
            FxRateUpload.find_by(id: upload_id)
          end

          def save_file_path!(upload:, file_path:)
            upload.update!(file_path: file_path)
            upload
          end

          def mark_success!(upload:, message:)
            upload.update!(
              status: "success",
              error_count: 0,
              error_message: message,
              processed_at: Time.current
            )
          end

          def mark_error!(upload:, error_count:, error_message:)
            upload.update!(
              status: "error",
              error_count: error_count,
              error_message: error_message,
              processed_at: Time.current
            )
          end

          def mark_exception!(upload:, message:)
            upload.update!(
              status: "error",
              error_count: [upload.error_count.to_i, 1].max,
              error_message: message,
              processed_at: Time.current
            )
          end
        end
      end
    end
  end
end
