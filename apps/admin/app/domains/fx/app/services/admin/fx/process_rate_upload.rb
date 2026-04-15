# frozen_string_literal: true

module Admin
  module Fx
    class ProcessRateUpload
      def initialize(
        repository: Admin::Fx::Repositories::ActiveRecord::RateUploadRepository.new,
        importer: Admin::Fx::RateUploadImporter
      )
        @repository = repository
        @importer = importer
      end

      def call(upload_id:)
        upload = @repository.find(upload_id)
        result = @importer.call(
          file_path: upload.file_path,
          created_by_id: upload.created_by_id,
          created_by_role: upload.created_by_role,
          created_context: upload.created_context,
          source_upload_id: upload.id
        )

        if result.valid?
          @repository.mark_success!(upload: upload, message: result.message)
        else
          @repository.mark_error!(
            upload: upload,
            error_count: result.errors.size,
            error_message: result.errors.first&.dig(:message)
          )
        end

        upload
      rescue StandardError
        @repository.mark_exception!(upload: upload, message: $!.message) if upload
        raise
      end
    end
  end
end
