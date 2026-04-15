# frozen_string_literal: true

require 'fileutils'
require 'securerandom'

module Admin
  module Fx
    class StartRateUpload
      def initialize(repository: Admin::Fx::Repositories::ActiveRecord::RateUploadRepository.new)
        @repository = repository
      end

      def call(file:, created_by_id:, created_by_role:, created_context:)
        upload = @repository.create_processing!(
          created_by_id: created_by_id,
          created_by_role: created_by_role,
          created_context: created_context,
          original_filename: file.original_filename
        )

        file_path = persist_file(file, upload.id)
        @repository.save_file_path!(upload: upload, file_path: file_path)
      end

      private

      def persist_file(file, upload_id)
        directory = Rails.root.join('tmp', 'fx_rate_uploads')
        FileUtils.mkdir_p(directory)
        file_path = directory.join("#{upload_id}-#{SecureRandom.hex(6)}.xlsx")
        File.binwrite(file_path, file.read)
        file_path.to_s
      end
    end
  end
end
