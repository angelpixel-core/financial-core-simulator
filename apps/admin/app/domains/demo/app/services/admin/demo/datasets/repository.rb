# frozen_string_literal: true

module Admin
  module Demo
    module Datasets
      class Repository
        def initialize(
          run_repository: Admin::DemoDataset::Repositories::ActiveRecord::RunRepository.new,
          upload_repository: Admin::DemoDataset::Repositories::ActiveRecord::UploadRepository.new
        )
          @run_repository = run_repository
          @upload_repository = upload_repository
        end

        def create_valid_trace!(input_json:, original_filename:)
          run = @run_repository.create_with_input!(input_json: input_json)
          upload = @upload_repository.create_valid!(run_id: run.id, original_filename: original_filename)
          [run, upload]
        end

        def create_invalid_trace!(errors:, original_filename:)
          @upload_repository.create_invalid!(validation_errors: errors, original_filename: original_filename)
        end

        def latest_upload
          @upload_repository.latest
        end

        def reset!
          @run_repository.delete_all!
          @upload_repository.delete_all!
        end
      end
    end
  end
end
