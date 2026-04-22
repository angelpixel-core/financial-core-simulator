# frozen_string_literal: true

module Admin
  module Demo
    module Access
      Result = Struct.new(:granted, :owner, :expires_at, keyword_init: true)

      module_function

      def acquire(account_id:, account_email: nil, now: Time.current)
        return Result.new(granted: true, owner: nil, expires_at: nil) unless enabled?
        return Result.new(granted: false, owner: nil, expires_at: nil) if account_id.blank?

        lock = DemoAccessLock.current
        expires_at = now + lock_ttl_seconds

        lock.with_lock do
          lock.reload
          if releasable?(lock, account_id: account_id, now: now)
            lock.update!(
              holder_account_id: account_id.to_s,
              holder_email: account_email.to_s.presence,
              acquired_at: now,
              expires_at: expires_at
            )

            return Result.new(granted: true, owner: owner_from(lock), expires_at: expires_at)
          end

          Result.new(granted: false, owner: owner_from(lock), expires_at: lock.expires_at)
        end
      end

      def release(account_id:)
        return true unless enabled?
        return false if account_id.blank?

        lock = DemoAccessLock.current
        lock.with_lock do
          lock.reload
          return false unless lock.held_by_account_id?(account_id)

          lock.update!(holder_account_id: nil, holder_email: nil, acquired_at: nil, expires_at: nil)
        end

        true
      end

      def current_user(now: Time.current)
        return nil unless enabled?

        lock = DemoAccessLock.current
        return nil if lock.expires_at.blank?

        if lock.expires_at <= now
          clear_stale_lock!(lock)
          return nil
        end

        owner_from(lock)
      end

      def lock_state(current_account_id:, now: Time.current)
        owner = current_user(now: now)
        return :available unless enabled?
        return :available if owner.nil?
        return :mine if owner[:account_id].to_s == current_account_id.to_s

        :in_use
      end

      def enabled?
        ENV.fetch("DEMO_LOCK_ENABLED", "0") == "1"
      end

      def lock_ttl_seconds
        value = ENV["DEMO_LOCK_TTL_SECONDS"].to_i
        value.positive? ? value : 900
      end

      def status_text(current_account_id:, now: Time.current)
        case lock_state(current_account_id: current_account_id, now: now)
        when :in_use then "demo_in_use"
        else "demo_available"
        end
      end

      def owner_from(lock)
        return nil if lock.holder_account_id.blank?

        {
          account_id: lock.holder_account_id,
          email: lock.holder_email,
          acquired_at: lock.acquired_at,
          expires_at: lock.expires_at
        }
      end
      private_class_method :owner_from

      def releasable?(lock, account_id:, now:)
        lock.holder_account_id.blank? || lock.held_by_account_id?(account_id) || lock.expires_at.blank? || lock.expires_at <= now
      end
      private_class_method :releasable?

      def clear_stale_lock!(lock)
        lock.with_lock do
          lock.reload
          return if lock.expires_at.present? && lock.expires_at > Time.current

          lock.update!(holder_account_id: nil, holder_email: nil, acquired_at: nil, expires_at: nil)
        end
      end
      private_class_method :clear_stale_lock!
    end
  end
end
