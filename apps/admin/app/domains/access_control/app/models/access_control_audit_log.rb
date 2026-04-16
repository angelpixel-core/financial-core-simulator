# frozen_string_literal: true

class AccessControlAuditLog < ApplicationRecord
  OUTCOMES = %w[allow deny].freeze

  belongs_to :account, optional: true

  validates :action, presence: true
  validates :outcome, presence: true, inclusion: {in: OUTCOMES}
end
