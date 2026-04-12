# frozen_string_literal: true

module FCS
  module Application
    module Base
      class Metrics
        def initialize(enabled: true)
          @enabled = enabled
        end

        def enabled?
          @enabled
        end

        def increment(_metric, tags: {})
          return unless enabled?

          raise NotImplementedError, "increment must be implemented"
        end

        def observe(_metric, _value, tags: {})
          return unless enabled?

          raise NotImplementedError, "observe must be implemented"
        end
      end

      class NoopMetrics < Metrics
        def increment(_metric, tags: {})
        end

        def observe(_metric, _value, tags: {})
        end
      end
    end
  end
end
