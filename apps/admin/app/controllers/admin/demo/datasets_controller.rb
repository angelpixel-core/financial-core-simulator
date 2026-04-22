# frozen_string_literal: true

module Admin
  module Demo
    class DatasetsController < ApplicationController
      include AdminUiAuthorizable

      before_action :authorize_admin_session_operator!
      before_action :authorize_demo_dataset_policy!
      before_action :ensure_demo_lock_access!, only: %i[create preview reset]

      def create
        file = params[:file]
        if file.blank?
          respond_upload_create_error(
            message: t("admin.overview.dataset.flash.missing_file"),
            code: "MISSING_FILE"
          )
          return
        end

        if upload_file_too_large?(file)
          respond_upload_create_error(
            message: t("admin.overview.dataset.flash.file_too_large", max_mb: Admin::UploadLimits.max_upload_file_size_mb),
            code: "FILE_SIZE_EXCEEDED"
          )
          return
        end

        original_filename = normalize_upload_filename(file.original_filename)
        if duplicate_filename?(original_filename)
          respond_upload_create_error(
            message: t("admin.overview.dataset.flash.duplicate_file", file_name: original_filename),
            code: "DUPLICATE_FILE"
          )
          return
        end

        result = Admin::Demo::Datasets::ExcelToInputParser.call(
          file_path: file.path,
          timeline_enabled: true
        )
        input = result.input
        trades = input.is_a?(Hash) ? Array(fetch_input_value(input, :trades)) : []

        if trades.any?
          run = ::Run.create!(input_json: input)
          fee_model = fetch_input_value(input, :feeModel)
          fee_enabled = fee_model.is_a?(Hash) ? (fee_model[:enabled] || fee_model["enabled"]) : false
          with_timeline_env do
            executed_run = ::Runs::Execute.new.call(run, fee_enabled: fee_enabled)
            run = executed_run if executed_run.is_a?(::Run)
            ::Runs::VerifyInputHash.new.call(run.reload)
          end
          parser_errors = normalize_parser_errors(result.errors)
          persist_parser_validation_errors(run, parser_errors)
          if parser_errors.present? && run.succeeded?
            run.update!(
              status: :succeeded,
              reliable: false,
              error_code: nil,
              error_message: nil
            )
          end

          upload_status = parser_errors.present? ? :invalid : :valid
          upload = ::DemoDatasetUpload.create!(
            status: upload_status,
            run_id: run.id,
            validation_errors: parser_errors,
            original_filename: original_filename
          )
          Admin::Fx::UploadRateGapProcessor.call(
            input: input,
            run: run,
            upload: upload,
            reporting_currency: ::ReportingSetting.current.reporting_currency
          )
          message_key = parser_errors.present? ? "admin.overview.dataset.flash.partial" : "admin.overview.dataset.flash.valid"
          respond_upload_create_success(
            message: t(message_key),
            run: run,
            upload: upload,
            parser_errors: parser_errors
          )
        else
          upload = ::DemoDatasetUpload.create!(
            status: :invalid,
            validation_errors: result.errors,
            original_filename: original_filename
          )
          respond_upload_create_error(
            message: t("admin.overview.dataset.flash.invalid"),
            code: "INVALID_DATASET",
            errors: result.errors,
            upload: upload
          )
        end
      end

      def reset
        Admin::Demo::Sandbox::Reset.new.call(trigger: "manual")
        redirect_to admin_overview_path(locale: I18n.locale), notice: t("admin.overview.dataset.flash.reset")
      end

      def preview
        file = params[:file]
        if file.blank?
          render_preview(state: :error, errors: [{code: "MISSING_FILE"}], status: :unprocessable_content)
          return
        end

        if upload_file_too_large?(file, stage: :preview)
          render_preview(
            state: :invalid,
            errors: [
              {
                code: "FILE_SIZE_EXCEEDED",
                message: t("admin.overview.dataset.flash.file_too_large", max_mb: Admin::UploadLimits.max_upload_file_size_mb)
              }
            ],
            status: :unprocessable_content,
            file_name: file.original_filename
          )
          return
        end

        result = Admin::Demo::Datasets::ExcelToInputParser.call(
          file_path: file.path,
          timeline_enabled: true
        )
        input = result.input
        summary = build_preview_summary(input)
        sample_rows = if input.is_a?(Hash)
          Array(fetch_input_value(input, :trades))
        else
          []
        end
        sample_rows = sample_rows.first(Admin::Demo::Datasets::ExcelToInputParser::MAX_PREVIEW_ROWS)
        preview_errors = Array(result.errors).first(Admin::Demo::Datasets::ExcelToInputParser::MAX_PREVIEW_ERRORS)
        sample_rows_truncated = Array(fetch_input_value(input, :trades)).size > sample_rows.size
        errors_truncated = Array(result.errors).size > preview_errors.size

        render_preview(
          state: result.valid? ? :success : :invalid,
          summary: summary,
          sample_rows: sample_rows,
          errors: preview_errors,
          sample_rows_truncated: sample_rows_truncated,
          errors_truncated: errors_truncated,
          file_name: file.original_filename
        )
      rescue => e
        render_preview(
          state: :error,
          errors: [{code: "PARSE_FAILED", message: e.message}],
          status: :unprocessable_content,
          file_name: file&.respond_to?(:original_filename) ? file.original_filename : nil
        )
      end

      private

      def authorize_demo_dataset_policy!
        authorize_policy!(Admin::Demo::DatasetPolicy, :"#{action_name}?", record: :demo_dataset)
      end

      def render_preview(state:, summary: nil, sample_rows: [], errors: [], status: :ok, file_name: nil, sample_rows_truncated: false,
        errors_truncated: false)
        if request.format.json?
          render json: {
            state: state,
            summary: summary,
            sample_rows: sample_rows,
            errors: errors,
            file_name: file_name,
            sample_rows_truncated: sample_rows_truncated,
            errors_truncated: errors_truncated
          }, status: status
          return
        end

        @state = state
        @summary = summary
        @sample_rows = sample_rows
        @errors = errors
        @file_name = file_name
        @sample_rows_truncated = sample_rows_truncated
        @errors_truncated = errors_truncated

        render "admin/demo/datasets/preview", status: status
      end

      def build_preview_summary(input)
        return nil unless input.is_a?(Hash)

        fee_model = fetch_input_value(input, :feeModel)

        {
          trades_count: Array(fetch_input_value(input, :trades)).size,
          accounts_count: Array(fetch_input_value(input, :accounts)).size,
          markets_count: Array(fetch_input_value(input, :markets)).size,
          schema_version: fetch_input_value(input, :schemaVersion),
          fee_enabled: fee_model.is_a?(Hash) ? (fee_model[:enabled] || fee_model["enabled"]) : nil
        }
      end

      def fetch_input_value(input, key)
        return input[key] if input.key?(key)

        input[key.to_s]
      end

      def normalize_parser_errors(errors)
        Array(errors).map do |error|
          normalized = error.respond_to?(:to_h) ? error.to_h.symbolize_keys : {}
          {
            line: normalized[:line],
            code: normalized[:code],
            source: normalized[:source].presence || "dataset_upload",
            row_index: normalized[:row_index],
            trade_id: normalized[:trade_id],
            account_id: normalized[:account_id],
            market_id: normalized[:market_id]
          }
        end
      end

      def persist_parser_validation_errors(run, errors)
        return if errors.blank?

        correlation_id = run.run_uuid.presence || "run-#{run.id}"
        now = Time.current
        entries = errors.map do |error|
          {
            run_id: run.id,
            source: error[:source],
            field: "trades",
            message: error[:code].to_s,
            code: error[:code],
            trade_id: error[:trade_id],
            account_id: error[:account_id],
            market_id: error[:market_id],
            row_index: error[:row_index],
            correlation_id: correlation_id,
            created_at: now,
            updated_at: now
          }
        end

        entries.each_slice(1_000) do |batch|
          ::RunValidationError.insert_all(batch)
        end
      end

      def with_timeline_env
        previous = ENV.fetch("FCS_TIMELINE_ENABLED", nil)
        ENV["FCS_TIMELINE_ENABLED"] = "1"
        yield
      ensure
        if previous.nil?
          ENV.delete("FCS_TIMELINE_ENABLED")
        else
          ENV["FCS_TIMELINE_ENABLED"] = previous
        end
      end

      def normalize_upload_filename(value)
        stripped = value.to_s.strip
        return stripped if stripped.present?

        "dataset_#{Time.current.utc.strftime("%Y%m%d%H%M%S")}.xlsx"
      end

      def duplicate_filename?(filename)
        normalized = ::DemoDatasetUpload.normalize_filename(filename)
        return false if normalized.blank?

        ::DemoDatasetUpload.exists?(normalized_filename: normalized)
      end

      def upload_file_too_large?(file, stage: :process)
        return false unless Admin::UploadLimits.exceeds_file_size?(file: file)

        Admin::UploadTelemetry.rejection(
          domain: "demo",
          stage: stage,
          reason: "file_size_exceeded",
          max_file_size_bytes: Admin::UploadLimits.max_upload_file_size_bytes,
          file_size_bytes: Admin::UploadLimits.file_size_bytes(file: file),
          original_filename: file.original_filename
        )
        true
      end

      def ensure_demo_lock_access!
        return if !Admin::Demo::Access.enabled? || current_admin_account.blank?

        result = Admin::Demo::Access.acquire(
          account_id: current_admin_account.id,
          account_email: current_admin_account.email
        )
        return if result.granted

        owner_label = result.owner&.dig(:email).presence || t("admin.overview.dataset.lock.unknown_owner")
        message = t("admin.overview.dataset.lock.in_use_by", owner: owner_label)

        if action_name == "preview"
          render_preview(
            state: :invalid,
            errors: [{code: "DEMO_LOCKED", message: message}],
            status: :locked
          )
          return
        end

        respond_upload_create_error(message: message, code: "DEMO_LOCKED")
      end

      def respond_upload_create_error(message:, code:, errors: nil, upload: nil)
        if request.format.json?
          render json: {
            state: "invalid",
            code: code,
            message: message,
            errors: Array(errors),
            upload_id: upload&.id
          }, status: :unprocessable_content
          return
        end

        redirect_to admin_overview_path(locale: I18n.locale), alert: message
      end

      def respond_upload_create_success(message:, run:, upload:, parser_errors:)
        if request.format.json?
          render json: {
            state: parser_errors.present? ? "partial" : "success",
            message: message,
            run_id: run.id,
            upload_id: upload.id,
            parser_errors_count: parser_errors.size
          }, status: :ok
          return
        end

        redirect_to admin_overview_path(locale: I18n.locale), notice: message
      end
    end
  end
end
