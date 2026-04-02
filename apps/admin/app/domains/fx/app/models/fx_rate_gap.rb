# frozen_string_literal: true

class FxRateGap < ApplicationRecord
  STATUSES = %w[open resolved ignored].freeze
  CURRENCY_CODE_FORMAT = /\A[A-Z]{3}\z/

  belongs_to :placeholder_rate, class_name: "FxDailyRate", optional: true
  belongs_to :resolved_rate, class_name: "FxDailyRate", optional: true
  belongs_to :source_run, class_name: "Run", optional: true
  belongs_to :source_upload, class_name: "DemoDatasetUpload", optional: true

  validates :operational_date, presence: true
  validates :base_currency, presence: true, format: {with: CURRENCY_CODE_FORMAT}
  validates :quote_currency, presence: true, format: {with: CURRENCY_CODE_FORMAT}
  validates :status, presence: true, inclusion: {in: STATUSES}
  validate :validate_resolution

  before_validation :normalize_currencies

  scope :open_status, -> { where(status: "open") }

  def self.open_for(operational_date:, base_currency:, quote_currency:)
    open_status.find_by(
      operational_date: operational_date,
      base_currency: base_currency.to_s.upcase,
      quote_currency: quote_currency.to_s.upcase
    )
  end

  def resolve!(rate:)
    update!(
      status: "resolved",
      resolved_rate: rate,
      resolved_at: Time.current
    )
  end

  def ignore!(reason: nil)
    context = created_context || {}
    context = context.merge("ignored_reason" => reason) if reason.present?
    update!(
      status: "ignored",
      ignored_at: Time.current,
      created_context: context
    )
  end

  private

  def normalize_currencies
    self.base_currency = base_currency.to_s.upcase
    self.quote_currency = quote_currency.to_s.upcase
  end

  def validate_resolution
    return unless status == "resolved"
    return if resolved_rate_id.present?

    errors.add(:resolved_rate_id, "is required when resolved")
  end
end
