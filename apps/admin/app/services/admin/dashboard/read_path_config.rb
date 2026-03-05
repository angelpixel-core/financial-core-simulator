module Admin
  module Dashboard
    class ReadPathConfig
      FEATURE_FLAG_KEY = "ADMIN_DASHBOARD_BFF_READ_ENABLED"
      FALLBACK_FLAG_KEY = "ADMIN_DASHBOARD_BFF_FALLBACK_ENABLED"

      def initialize(env: ENV)
        @env = env
      end

      def bff_read_enabled?
        parse_boolean(FEATURE_FLAG_KEY)
      end

      def fallback_enabled?
        parse_boolean(FALLBACK_FLAG_KEY)
      end

      private

      def parse_boolean(key)
        ActiveModel::Type::Boolean.new.cast(@env[key])
      end
    end
  end
end
