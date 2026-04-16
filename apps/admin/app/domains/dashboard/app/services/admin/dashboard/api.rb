# frozen_string_literal: true

module Admin
  module Dashboard
    module Api
      module_function

      def read_metrics
        Admin::Dashboard::ReadMetrics.new.call
      end

      def read_path_unavailable_error
        Admin::Dashboard::ReadMetrics::ReadPathUnavailableError
      end

      def compatibility_guard
        Admin::Dashboard::CompatibilityGuard.new
      end

      def compatibility_contract_version
        Admin::Dashboard::CompatibilityGuard::CONTRACT_VERSION
      end

      def overview_response_serializer(compatibility_guard:)
        Admin::Dashboard::OverviewResponseSerializer.new(compatibility_guard: compatibility_guard)
      end

      def widget_response_serializer(compatibility_guard:)
        Admin::Dashboard::WidgetResponseSerializer.new(compatibility_guard: compatibility_guard)
      end

      def financial_overview_response_serializer
        Admin::Dashboard::FinancialOverviewResponseSerializer.new
      end

      def ingestion_validation_errors_response_serializer
        Admin::Dashboard::IngestionValidationErrorsResponseSerializer.new
      end

      def financial_overview_metrics(run:, account_id: nil, market_id: nil)
        Admin::Dashboard::FinancialOverviewMetrics.new(run: run, account_id: account_id, market_id: market_id)
      end

      def seed_ingestion_validation_errors(source:, field:)
        Admin::Dashboard::SeedMetrics.new.ingestion_validation_errors(source: source, field: field)
      end

      def dashboard_metrics_ingestion_errors(source:, field:)
        Admin::DashboardMetrics.new.ingestion_validation_errors(source: source, field: field)
      end

      def read_path_config
        Admin::Dashboard::ReadPathConfig.new
      end

      def build_fx_context
        Admin::Dashboard::BuildFxContext.new.call
      end

      def find_run_by_id(run_id)
        Admin::Dashboard::Repositories::ActiveRecord::RunRepository.new.find_by_id(run_id)
      end

      def latest_demo_dataset_upload
        Admin::Dashboard::Repositories::ActiveRecord::DemoDatasetUploadRepository.new.latest
      end
    end
  end
end
