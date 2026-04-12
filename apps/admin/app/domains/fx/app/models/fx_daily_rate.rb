# frozen_string_literal: true

class FxDailyRate < ApplicationRecord
  SOURCES = %w[manual carry_forward upload placeholder].freeze
  CURRENCY_CODE_FORMAT = FCS::Currency::CODE_FORMAT

  has_one :placeholder_gap, class_name: "FxRateGap", foreign_key: :placeholder_rate_id, dependent: :nullify
  has_one :resolved_gap, class_name: "FxRateGap", foreign_key: :resolved_rate_id, dependent: :nullify

  validates :operational_date, presence: true
  validates :base_currency, presence: true, format: {with: CURRENCY_CODE_FORMAT}
  validates :quote_currency, presence: true, format: {with: CURRENCY_CODE_FORMAT}
  validates :rate, numericality: {greater_than: 0}, allow_nil: true
  validates :source, presence: true, inclusion: {in: SOURCES}
  validates :operational_date, uniqueness: {scope: %i[base_currency quote_currency]}

  before_validation :normalize_currencies
  validate :validate_placeholder_rate

  def placeholder?
    source == "placeholder"
  end

  def manual?
    source == "manual"
  end

  def linked_to_system?
    source_run_id.present? || source_upload_id.present? || resolved_gap.present?
  end

  def self.open_gap_for(operational_date:, base_currency:, quote_currency:)
    FxRateGap.open_for(
      operational_date: operational_date,
      base_currency: base_currency,
      quote_currency: quote_currency
    )
  end

  private

  def normalize_currencies
    self.base_currency = base_currency.to_s.upcase
    self.quote_currency = quote_currency.to_s.upcase
  end

  def validate_placeholder_rate
    if placeholder?
      errors.add(:rate, "must be blank for placeholder") if rate.present?
      return
    end

    errors.add(:rate, "is required") if rate.blank?
  end
end
