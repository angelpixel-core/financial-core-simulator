# frozen_string_literal: true

module Admin
  module Events
    class BusAdapter < FCS::Ports::EventBus
      NOTIFICATION_NAME = "admin.events.publish"

      def initialize(schema_router: Admin::Events::SchemaRouter.new)
        @schema_router = schema_router
      end

      def publish(event_name, payload = {})
        envelope = @schema_router.route(event_name: event_name, payload: payload)
        ActiveSupport::Notifications.instrument(NOTIFICATION_NAME, envelope)
        envelope
      end
    end
  end
end
