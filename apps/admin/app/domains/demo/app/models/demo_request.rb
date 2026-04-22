# frozen_string_literal: true

class DemoRequest < ApplicationRecord
  PREFERRED_CONTACTS = %w[email video_call user_provisioning].freeze
  STATUSES = %w[pending contacted provisioned closed].freeze

  before_validation :normalize_fields

  validates :name, presence: true
  validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}
  validates :company, presence: true
  validates :preferred_contact, presence: true, inclusion: {in: PREFERRED_CONTACTS}
  validates :status, presence: true, inclusion: {in: STATUSES}

  private

  def normalize_fields
    self.name = name.to_s.strip
    self.email = email.to_s.strip.downcase
    self.company = company.to_s.strip
    self.message = message.to_s.strip.presence
    self.preferred_contact = preferred_contact.to_s.strip
  end
end
