# frozen_string_literal: true

class DemoUsageEvent < ApplicationRecord
  ACTIONS = %w[login upload preview execution].freeze
  STATUSES = %w[allowed rejected].freeze

  validates :action, presence: true, inclusion: {in: ACTIONS}
  validates :status, presence: true, inclusion: {in: STATUSES}

  scope :recent_since, ->(time) { where("created_at >= ?", time) }
  scope :for_action, ->(action) { where(action: action) }
  scope :allowed, -> { where(status: "allowed") }
  scope :rejected, -> { where(status: "rejected") }
  scope :for_actor, ->(actor_id) { where(actor_id: actor_id.to_s) }
end
