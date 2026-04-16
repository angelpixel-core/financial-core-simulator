# frozen_string_literal: true

module Admin
  module DemoDataset
    module Api
      module_function

      def process_upload(file_path:, timeline_enabled:)
        Admin::DemoDataset::ProcessUpload.new.call(
          file_path: file_path,
          timeline_enabled: timeline_enabled
        )
      end

      def preview_upload(file_path:, timeline_enabled:)
        Admin::DemoDataset::PreviewUpload.new.call(
          file_path: file_path,
          timeline_enabled: timeline_enabled
        )
      end

      def reset_data
        Admin::DemoDataset::ResetData.new.call
      end

      def generate_excel(output_dir:, kind:)
        generator = Admin::DemoDataset::ExcelGenerator.new(output_dir: output_dir)
        (kind == :invalid) ? generator.generate_invalid : generator.generate_valid
      end
    end
  end
end
