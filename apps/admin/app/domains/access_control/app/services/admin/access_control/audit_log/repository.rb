# frozen_string_literal: true

module Admin
  module AccessControl
    module AuditLog
      class Repository
        EVENT_NAME = 'access_control.authorization.checked'

        def initialize(event_bus: Admin::Events::BusAdapter.new)
          @event_bus = event_bus
        end

        def record!(action:, outcome:, account: nil, role: nil, required_role: nil, context: {})
          payload = {
            action: action.to_s,
            outcome: outcome.to_s,
            account_id: account&.id,
            role: role,
            required_role: required_role,
            context: context
          }

          log = AccessControlAuditLog.create!(payload)
          publish_event(payload.merge(id: log.id, occurred_at: log.created_at&.utc&.iso8601))
          log
        end

        private

        def publish_event(payload)
          @event_bus.publish(EVENT_NAME, payload)
        rescue StandardError
          nil
        end
      end
    end
  end
end
