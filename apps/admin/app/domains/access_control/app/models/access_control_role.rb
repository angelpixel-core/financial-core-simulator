# frozen_string_literal: true

class AccessControlRole < ApplicationRecord
  has_many :access_control_account_roles, dependent: :destroy
  has_many :accounts, through: :access_control_account_roles
  has_many :access_control_permissions, dependent: :destroy

  validates :key, presence: true, uniqueness: true
  validates :level, presence: true
end
