# frozen_string_literal: true

require 'fileutils'

module Admin
  module Runs
    module Artifacts
      class FileStoreAdapter < FCS::Ports::ArtifactStore
        def build_output_dir(run_id:)
          base = Rails.root.join('storage', 'runs')
          FileUtils.mkdir_p(base)

          dir = base.join("run_#{run_id}_#{Time.now.utc.strftime('%Y%m%dT%H%M%S')}")
          FileUtils.mkdir_p(dir)
          dir.to_s
        end

        def artifact_paths(output_dir:, execution_result:)
          artifacts = execution_result.fetch(:artifacts)

          {
            'result_json_path' => existing_or_nil(execution_result.fetch(:json_path)),
            'positions_csv_path' => existing_or_nil(artifacts[:positions_csv_path]),
            'pnl_csv_path' => existing_or_nil(artifacts[:pnl_csv_path])
          }
        end

        private

        def existing_or_nil(path)
          return nil if path.blank?

          expanded = File.expand_path(path)
          return expanded if File.exist?(expanded)

          candidate = Rails.root.join(path).to_s
          return candidate if File.exist?(candidate)

          nil
        end
      end
    end
  end
end
