class Account < ApplicationRecord
  include Rodauth::Rails.model

  enum :status, {unverified: 1, verified: 2, closed: 3}

  has_many :access_control_account_roles, dependent: :destroy
  has_many :access_control_roles, through: :access_control_account_roles
  has_many :access_control_audit_logs, dependent: :nullify
end
