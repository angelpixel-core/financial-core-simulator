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

      def call
        return read_from_seed if @read_path_config.seed_enabled?
        return read_from_bff_with_optional_fallback if @read_path_config.bff_read_enabled?

        read_from_artifact
      end

      private

      def read_from_bff_with_optional_fallback
        @bff_reader.call
      rescue => error
        return read_from_artifact if @read_path_config.fallback_enabled?

        raise ReadPathUnavailableError, "BFF read failed and fallback is disabled: #{error.message}"
      end

      def read_from_artifact
        @artifact_reader.call
      end

      def read_from_seed
        Admin::Dashboard::SeedMetrics.new.call
      end
    end
  end
end
