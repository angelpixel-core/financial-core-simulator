# frozen_string_literal: true

module Admin
  module Observability
    class PrometheusMetricsAdapter
      NOTIFICATION_NAME = 'admin.observability.metric'

      def increment(metric_name, tags: {}, value: 1)
        emit(type: 'counter', metric: metric_name, value: value, tags: tags)
      end

      def observe(metric_name, value:, tags: {})
        emit(type: 'histogram', metric: metric_name, value: value, tags: tags)
      end

      private

      def emit(type:, metric:, value:, tags:)
        payload = {
          type: type,
          metric: metric,
          value: value,
          tags: tags
        }
        ActiveSupport::Notifications.instrument(NOTIFICATION_NAME, payload)
        payload
      end
    end
  end
end
