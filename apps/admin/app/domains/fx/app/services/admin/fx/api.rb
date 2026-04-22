# frozen_string_literal: true

module Admin
  module Fx
    module Api
      module_function

      def history_snapshot(sort_order:, source_id: nil)
        Admin::Fx::HistorySnapshot.call(sort_order: sort_order, source_id: source_id)
      end

      def reporting_settings_update(reporting_currency:, updated_by_id:, updated_by_role:, updated_context:)
        Admin::Fx::ReportingSettingsUpdater.call(
          reporting_currency: reporting_currency,
          updated_by_id: updated_by_id,
          updated_by_role: updated_by_role,
          updated_context: updated_context
        )
      end

      def upsert_rate(operational_date:, base_currency:, quote_currency:, rate:, created_by_id:, created_by_role:,
        created_context:)
        Admin::Fx::RateUpserter.call(
          operational_date: operational_date,
          base_currency: base_currency,
          quote_currency: quote_currency,
          rate: rate,
          created_by_id: created_by_id,
          created_by_role: created_by_role,
          created_context: created_context
        )
      end

      def carry_forward_rate(operational_date:, base_currency:, quote_currency:, created_by_id:, created_by_role:,
        created_context:)
        Admin::Fx::CarryForwardRate.call(
          operational_date: operational_date,
          base_currency: base_currency,
          quote_currency: quote_currency,
          source: "carry_forward",
          created_by_id: created_by_id,
          created_by_role: created_by_role,
          created_context: created_context
        )
      end

      def update_rate(rate_id:, rate:, created_by_id:, created_by_role:, created_context:)
        Admin::Fx::UpdateDailyRate.new.call(
          rate_id: rate_id,
          rate: rate,
          created_by_id: created_by_id,
          created_by_role: created_by_role,
          created_context: created_context
        )
      end

      def delete_rate(rate_id:)
        Admin::Fx::DeleteDailyRate.new.call(rate_id: rate_id)
      end

      def operational_date(value: nil)
        return Admin::Fx::OperationalDate.call if value.blank?

        Date.iso8601(value)
      rescue ArgumentError
        Admin::Fx::OperationalDate.call
      end

      def base_currency
        Admin::Fx::RateResolver::BASE_CURRENCY
      end

      def start_rate_upload(file:, created_by_id:, created_by_role:, created_context:)
        Admin::Fx::StartRateUpload.new.call(
          file: file,
          created_by_id: created_by_id,
          created_by_role: created_by_role,
          created_context: created_context
        )
      end

      def enqueue_rate_upload(upload_id)
        Admin::Fx::RateUploadJob.perform_later(upload_id)
      end

      def preview_rate_upload(file_path:)
        Admin::Fx::RateUploadPreview.call(file_path: file_path)
      end

      def clear_daily_rates
        FxDailyRate.delete_all
      end

      def mark_upload_exception(upload:, message:)
        Admin::Fx::Repositories::ActiveRecord::RateUploadRepository.new.mark_exception!(
          upload: upload,
          message: message
        )
      end

      def generate_rate_upload_template
        Admin::Fx::RateUploadTemplate.generate
      end

      def visible_rate_upload(upload_id:, account_id:)
        FxRateUpload.visible_for_upload(upload_id: upload_id, account_id: account_id)
      end

      def rate_upload_status_stream(account_id:)
        history_stream(account_id: account_id)
      end

      def history_stream(account_id:)
        FxRateUpload.status_stream_for(account_id: account_id)
      end

      def active_sources
        Admin::Fx::SourceCatalog.active_sources
      end

      def available_markets_for(source:)
        Admin::Fx::SourceCatalog.available_markets_for(source)
      end

      def sync_date_range(source:, date_from_param:, date_to_param:)
        Admin::Fx::SyncDateRange.resolve(
          source: source,
          date_from_param: date_from_param,
          date_to_param: date_to_param
        )
      end
    end
  end
end
