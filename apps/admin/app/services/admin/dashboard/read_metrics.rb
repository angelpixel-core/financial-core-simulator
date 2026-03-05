module Admin
  module Dashboard
    class ReadMetrics
      FEATURE_FLAG_KEY = "ADMIN_DASHBOARD_BFF_READ_ENABLED"

      def initialize(
        env: ENV,
        bff_reader: Admin::Dashboard::BffReadMetrics.new,
        artifact_reader: Admin::DashboardMetrics.new
      )
        @env = env
        @bff_reader = bff_reader
        @artifact_reader = artifact_reader
      end

      def call
        return @artifact_reader.call unless bff_read_enabled?

        @bff_reader.call
      end

      private

      def bff_read_enabled?
        ActiveModel::Type::Boolean.new.cast(@env[FEATURE_FLAG_KEY])
      end
    end
  end
end
