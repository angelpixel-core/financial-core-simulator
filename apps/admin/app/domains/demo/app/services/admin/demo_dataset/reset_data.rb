# frozen_string_literal: true

require 'fileutils'

module Admin
  module DemoDataset
    class ResetData
      def initialize(
        run_repository: Admin::DemoDataset::Repositories::ActiveRecord::RunRepository.new,
        upload_repository: Admin::DemoDataset::Repositories::ActiveRecord::UploadRepository.new
      )
        @run_repository = run_repository
        @upload_repository = upload_repository
      end

      def call
        @run_repository.delete_all!
        @upload_repository.delete_all!
        FileUtils.rm_rf(Rails.root.join('storage', 'runs'))
      end
    end
  end
end
