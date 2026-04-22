# frozen_string_literal: true

require "fileutils"
require "json"

module Admin
  module Demo
    module Sandbox
      class Reset
        EVENT_NAME = "admin.demo.sandbox_reset"
        FX_UPLOAD_SOURCE = "fx_history_upload"

        def call(trigger: "recurring")
          started_at = Time.current
          monotonic_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          state = DemoSandboxState.current

          state.update!(last_reset_status: "running")
          log_info(event: "started", trigger: trigger, started_at: started_at.iso8601)

          result, artifacts = perform_reset

          duration_ms = elapsed_ms(monotonic_started_at)
          cleanup_artifacts(artifacts)

          state.update!(
            last_reset_at: Time.current,
            last_reset_status: "success",
            last_reset_duration_ms: duration_ms,
            last_reset_result: result
          )

          payload = {
            event: EVENT_NAME,
            status: "success",
            trigger: trigger,
            duration_ms: duration_ms,
            result: result
          }
          ActiveSupport::Notifications.instrument(EVENT_NAME, payload)
          Rails.logger.info(payload.to_json)
          result
        rescue => e
          duration_ms = elapsed_ms(monotonic_started_at)
          DemoSandboxState.current.update!(
            last_reset_at: Time.current,
            last_reset_status: "failed",
            last_reset_duration_ms: duration_ms,
            last_reset_result: {
              "error_class" => e.class.name,
              "error_message" => e.message
            }
          )

          payload = {
            event: EVENT_NAME,
            status: "failed",
            trigger: trigger,
            duration_ms: duration_ms,
            error_class: e.class.name,
            error_message: e.message
          }
          ActiveSupport::Notifications.instrument(EVENT_NAME, payload)
          Rails.logger.error(payload.to_json)
          raise
        end

        private

        def perform_reset
          result = {
            "runs" => 0,
            "demo_dataset_uploads" => 0,
            "fx_daily_rates" => 0,
            "fx_rate_gaps" => 0,
            "fx_rate_uploads" => 0
          }
          artifacts = {
            run_output_dirs: [],
            fx_upload_files: []
          }

          ActiveRecord::Base.transaction do
            demo_upload_ids = DemoDatasetUpload.order(:id).pluck(:id)
            run_ids = DemoDatasetUpload.where.not(run_id: nil).distinct.order(:run_id).pluck(:run_id)

            artifacts[:run_output_dirs] = Run.where(id: run_ids).pluck(:output_dir).compact

            demo_fx_uploads = FxRateUpload.where("created_context ->> 'source' = ?", FX_UPLOAD_SOURCE)
            demo_fx_upload_ids = demo_fx_uploads.pluck(:id)
            artifacts[:fx_upload_files] = demo_fx_uploads.pluck(:file_path).compact

            result["fx_rate_gaps"] = demo_fx_gap_scope(run_ids: run_ids, demo_upload_ids: demo_upload_ids).delete_all
            result["fx_daily_rates"] = demo_fx_daily_rate_scope(
              run_ids: run_ids,
              demo_upload_ids: demo_upload_ids,
              demo_fx_upload_ids: demo_fx_upload_ids
            ).delete_all

            result["fx_rate_uploads"] = demo_fx_uploads.delete_all

            runs_to_delete = Run.where(id: run_ids).to_a
            runs_to_delete.each(&:destroy!)
            result["runs"] = runs_to_delete.size

            result["demo_dataset_uploads"] = DemoDatasetUpload.where(id: demo_upload_ids).delete_all
          end

          [result, artifacts]
        end

        def demo_fx_gap_scope(run_ids:, demo_upload_ids:)
          scope = FxRateGap.none
          scope = scope.or(FxRateGap.where(source_run_id: run_ids)) if run_ids.any?
          scope = scope.or(FxRateGap.where(source_upload_id: demo_upload_ids)) if demo_upload_ids.any?
          scope
        end

        def demo_fx_daily_rate_scope(run_ids:, demo_upload_ids:, demo_fx_upload_ids:)
          scope = FxDailyRate.none
          scope = scope.or(FxDailyRate.where(source_run_id: run_ids)) if run_ids.any?
          if demo_upload_ids.any?
            scope = scope.or(FxDailyRate.where(source: "placeholder", source_upload_id: demo_upload_ids))
          end
          if demo_fx_upload_ids.any?
            scope = scope.or(FxDailyRate.where(source: "upload", source_upload_id: demo_fx_upload_ids))
          end
          scope
        end

        def cleanup_artifacts(artifacts)
          cleanup_run_output_dirs(Array(artifacts[:run_output_dirs]))
          cleanup_fx_upload_files(Array(artifacts[:fx_upload_files]))
        end

        def cleanup_run_output_dirs(paths)
          base_dir = Rails.root.join("storage", "runs").to_s
          paths.each do |path|
            next if path.blank?

            expanded = File.expand_path(path)
            next unless expanded.start_with?(base_dir)

            FileUtils.rm_rf(expanded)
          end
        end

        def cleanup_fx_upload_files(paths)
          paths.each do |path|
            next if path.blank?

            FileUtils.rm_f(path)
          end
        end

        def elapsed_ms(monotonic_started_at)
          return nil if monotonic_started_at.nil?

          ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - monotonic_started_at) * 1000).to_i
        rescue
          nil
        end

        def log_info(payload)
          Rails.logger.info(payload.to_json)
        end
      end
    end
  end
end
