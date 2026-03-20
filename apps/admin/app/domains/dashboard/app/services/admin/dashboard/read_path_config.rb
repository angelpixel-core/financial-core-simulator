module Admin
  module Dashboard
    class ReadPathConfig
      FEATURE_FLAG_KEY = "ADMIN_DASHBOARD_BFF_READ_ENABLED"
      FALLBACK_FLAG_KEY = "ADMIN_DASHBOARD_BFF_FALLBACK_ENABLED"
      SEED_FLAG_KEY = "ADMIN_DASHBOARD_SEED_ENABLED"
      TRUE_VALUES = %w[1 true on yes].freeze

      def initialize(env: ENV)
        @env = env
      end

      def bff_read_enabled?
        parse_boolean(FEATURE_FLAG_KEY)
      end

      def fallback_enabled?
        parse_boolean(FALLBACK_FLAG_KEY)
      end

      def seed_enabled?
        parse_boolean(SEED_FLAG_KEY)
      end

      private

      def parse_boolean(key)
        value = @env[key].to_s.strip.downcase
        TRUE_VALUES.include?(value)
      end
    end
  end
end
