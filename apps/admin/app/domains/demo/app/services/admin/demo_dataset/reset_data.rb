# frozen_string_literal: true

require "fileutils"

module Admin
  module DemoDataset
    class ResetData
      def initialize(repository: Admin::Demo::Datasets::Repository.new)
        @repository = repository
      end

      def call
        @repository.reset!
        FileUtils.rm_rf(Rails.root.join("storage", "runs"))
      end
    end
  end
end
