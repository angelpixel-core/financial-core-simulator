# frozen_string_literal: true

require "json"

module Admin
  module UploadTelemetry
    EVENT_NAME = "admin.upload.rejected"

    module_function

    def rejection(domain:, stage:, reason:, **context)
      payload = {
        event: EVENT_NAME,
        domain: domain,
        stage: stage,
        reason: reason
      }.merge(context.compact)

      ActiveSupport::Notifications.instrument(EVENT_NAME, payload)
      Rails.logger.warn(payload.to_json)
    end
  end
end
