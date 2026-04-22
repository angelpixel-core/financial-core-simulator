# frozen_string_literal: true

module Admin
  module DemoDataset
    class PreviewUpload
      def initialize(
        file_adapter: Admin::Demo::Datasets::FileAdapter.new,
        presenter: Admin::Demo::Datasets::PreviewPresenter.new
      )
        @file_adapter = file_adapter
        @presenter = presenter
      end

      def call(file_path:, timeline_enabled:)
        result = @file_adapter.parse(file_path: file_path, timeline_enabled: timeline_enabled, stage: :preview)
        @presenter.present(result)
      end
    end
  end
end
