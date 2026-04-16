# frozen_string_literal: true

class AccessControlAccountRole < ApplicationRecord
  belongs_to :account
  belongs_to :access_control_role

  validates :account_id, uniqueness: { scope: :access_control_role_id }
end
