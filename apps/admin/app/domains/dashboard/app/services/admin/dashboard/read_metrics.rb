module Admin
  module Dashboard
    class ReadMetrics
      class ReadPathUnavailableError < StandardError; end

      def initialize(
        env: ENV,
        read_path_config: nil,
        bff_reader: Admin::Dashboard::BffReadMetrics.new,
        artifact_reader: Admin::DashboardMetrics.new
      )
        @read_path_config = read_path_config || Admin::Dashboard::ReadPathConfig.new(env: env)
        @bff_reader = bff_reader
        @artifact_reader = artifact_reader
      end

      def call(trades_window: "all-time")
        return read_from_seed(trades_window: trades_window) if @read_path_config.seed_enabled?
        return read_from_bff_with_optional_fallback(trades_window: trades_window) if @read_path_config.bff_read_enabled?

        read_from_artifact(trades_window: trades_window)
      end

      private

      def read_from_bff_with_optional_fallback(trades_window:)
        @bff_reader.call
      rescue => e
        return read_from_artifact(trades_window: trades_window) if @read_path_config.fallback_enabled?

        raise ReadPathUnavailableError, "BFF read failed and fallback is disabled: #{e.message}"
      end

      def read_from_artifact(trades_window:)
        @artifact_reader.call(trades_window: trades_window)
      end

      def read_from_seed(trades_window:)
        Admin::Dashboard::SeedMetrics.new.call(trades_window: trades_window)
      end
    end
  end
end
