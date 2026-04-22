# frozen_string_literal: true

class DemoSandboxState < ApplicationRecord
  STATUSES = %w[idle running success failed].freeze
  SINGLETON_KEY = "demo_sandbox"

  validates :singleton_key, presence: true, uniqueness: true
  validates :last_reset_status, inclusion: {in: STATUSES}

  def self.current
    find_or_create_by!(singleton_key: SINGLETON_KEY)
  end

  def status_key
    value = last_reset_status.to_s
    STATUSES.include?(value) ? value : "idle"
  end
end
