# frozen_string_literal: true

module Admin
  module Demo
    module AbuseProtection
      class LimitExceeded < StandardError
        attr_reader :code, :http_status

        def initialize(code:, message:, http_status: :too_many_requests)
          super(message)
          @code = code
          @http_status = http_status
        end
      end

      module_function

      def enforce_login!(request:, locale: I18n.locale)
        actor_id = actor_identifier(request: request)
        enforce_rate_limit!(
          action: "login",
          actor_id: actor_id,
          request: request,
          limit: env_integer("DEMO_RATE_LIMIT_LOGIN_PER_MINUTE", 10),
          window: 1.minute,
          code: "LOGIN_RATE_LIMIT_EXCEEDED",
          message: I18n.t("admin.overview.dataset.abuse.login_rate_limit_exceeded", locale: locale)
        )
      end

      def enforce_preview!(request:, account:, locale: I18n.locale)
        actor_id = actor_identifier(request: request, account: account)
        enforce_rate_limit!(
          action: "preview",
          actor_id: actor_id,
          request: request,
          limit: env_integer("DEMO_RATE_LIMIT_PREVIEW_PER_HOUR", 60),
          window: 1.hour,
          code: "PREVIEW_RATE_LIMIT_EXCEEDED",
          message: I18n.t("admin.overview.dataset.abuse.preview_rate_limit_exceeded", locale: locale)
        )
      end

      def enforce_manual_execution!(request:, account:, locale: I18n.locale)
        actor_id = actor_identifier(request: request, account: account)
        enforce_rate_limit!(
          action: "execution",
          actor_id: actor_id,
          request: request,
          limit: env_integer("DEMO_RATE_LIMIT_EXECUTION_PER_HOUR", 40),
          window: 1.hour,
          code: "EXECUTION_RATE_LIMIT_EXCEEDED",
          message: I18n.t("admin.overview.dataset.abuse.execution_rate_limit_exceeded", locale: locale)
        )
      end

      def enforce_upload!(request:, account:, file_size_bytes:, locale: I18n.locale)
        actor_id = actor_identifier(request: request, account: account)

        enforce_rate_limit!(
          action: "upload",
          actor_id: actor_id,
          request: request,
          limit: env_integer("DEMO_RATE_LIMIT_UPLOAD_PER_HOUR", 24),
          window: 1.hour,
          record_allowed: false,
          code: "UPLOAD_RATE_LIMIT_EXCEEDED",
          message: I18n.t("admin.overview.dataset.abuse.upload_rate_limit_exceeded", locale: locale)
        )

        now = Time.current
        uploads_last_hour = DemoUsageEvent
          .for_action("upload")
          .allowed
          .for_actor(actor_id)
          .recent_since(now - 1.hour)
          .count
        upload_quota_per_hour = env_integer("DEMO_QUOTA_UPLOADS_PER_HOUR", 12)
        if uploads_last_hour >= upload_quota_per_hour
          reject!(
            action: "upload",
            actor_id: actor_id,
            request: request,
            reason: "quota_uploads_per_hour",
            metadata: {uploads_last_hour: uploads_last_hour, quota: upload_quota_per_hour}
          )
          raise LimitExceeded.new(
            code: "UPLOAD_QUOTA_PER_HOUR_EXCEEDED",
            message: I18n.t("admin.overview.dataset.abuse.upload_quota_hour_exceeded", locale: locale)
          )
        end

        bytes_today = DemoUsageEvent
          .for_action("upload")
          .allowed
          .for_actor(actor_id)
          .where("created_at >= ?", now.beginning_of_day)
          .sum(:amount_bytes)
        quota_bytes_per_day = env_integer("DEMO_QUOTA_UPLOAD_VOLUME_MB_PER_DAY", 200).megabytes
        if bytes_today + file_size_bytes.to_i > quota_bytes_per_day
          reject!(
            action: "upload",
            actor_id: actor_id,
            request: request,
            reason: "quota_volume_per_day",
            metadata: {bytes_today: bytes_today, requested_bytes: file_size_bytes, quota_bytes: quota_bytes_per_day}
          )
          raise LimitExceeded.new(
            code: "UPLOAD_VOLUME_QUOTA_EXCEEDED",
            message: I18n.t("admin.overview.dataset.abuse.upload_volume_quota_exceeded", locale: locale)
          )
        end

        allow!(action: "upload", actor_id: actor_id, request: request, amount_bytes: file_size_bytes)
      end

      def record_allowed_request(action:, request:, account: nil)
        actor_id = actor_identifier(request: request, account: account)
        allow!(action: action, actor_id: actor_id, request: request)
      end

      def summary(now: Time.current)
        since = now - 24.hours
        scope = DemoUsageEvent.recent_since(since)

        {
          requests_24h: scope.count,
          uploads_24h: scope.for_action("upload").allowed.count,
          rejections_24h: scope.rejected.count
        }
      end

      def actor_identifier(request:, account: nil)
        return account.id.to_s if account&.id.present?

        header_user = request.headers["X-Admin-User"].to_s.strip
        return "user:#{header_user}" if header_user.present?

        "ip:#{request.remote_ip}"
      end

      def enforce_rate_limit!(action:, actor_id:, request:, limit:, window:, code:, message:, record_allowed: true)
        now = Time.current
        attempts = DemoUsageEvent
          .for_action(action)
          .for_actor(actor_id)
          .recent_since(now - window)
          .count

        if attempts >= limit
          reject!(
            action: action,
            actor_id: actor_id,
            request: request,
            reason: "rate_limit",
            metadata: {window_seconds: window.to_i, limit: limit}
          )
          raise LimitExceeded.new(code: code, message: message)
        end

        allow!(action: action, actor_id: actor_id, request: request) if record_allowed
      end
      private_class_method :enforce_rate_limit!

      def allow!(action:, actor_id:, request:, amount_bytes: 0, metadata: {})
        DemoUsageEvent.create!(
          action: action,
          status: "allowed",
          actor_id: actor_id,
          ip_address: request.remote_ip,
          amount_bytes: amount_bytes.to_i,
          metadata: metadata
        )
      end
      private_class_method :allow!

      def reject!(action:, actor_id:, request:, reason:, metadata: {})
        DemoUsageEvent.create!(
          action: action,
          status: "rejected",
          reason: reason,
          actor_id: actor_id,
          ip_address: request.remote_ip,
          amount_bytes: 0,
          metadata: metadata
        )
      end
      private_class_method :reject!

      def env_integer(key, default)
        value = ENV[key].to_i
        value.positive? ? value : default
      end
      private_class_method :env_integer
    end
  end
end
