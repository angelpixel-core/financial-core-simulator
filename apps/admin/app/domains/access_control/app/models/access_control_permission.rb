# frozen_string_literal: true

class AccessControlPermission < ApplicationRecord
  belongs_to :access_control_role

  validates :resource, presence: true
  validates :action, presence: true
  validates :access_control_role_id, uniqueness: { scope: %i[resource action] }
end
