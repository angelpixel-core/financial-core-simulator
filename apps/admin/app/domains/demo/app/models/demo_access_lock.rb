# frozen_string_literal: true

class DemoAccessLock < ApplicationRecord
  SINGLETON_KEY = "demo_access"

  validates :singleton_key, presence: true, uniqueness: true

  def self.current
    find_or_create_by!(singleton_key: SINGLETON_KEY)
  end

  def held_by_account_id?(account_id)
    holder_account_id.present? && holder_account_id.to_s == account_id.to_s
  end
end
