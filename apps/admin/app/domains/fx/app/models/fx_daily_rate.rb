# frozen_string_literal: true

class FxDailyRate < ApplicationRecord
  SOURCES = %w[manual carry_forward].freeze
  CURRENCY_CODE_FORMAT = /\A[A-Z]{3}\z/

  validates :operational_date, presence: true
  validates :base_currency, presence: true, format: { with: CURRENCY_CODE_FORMAT }
  validates :quote_currency, presence: true, format: { with: CURRENCY_CODE_FORMAT }
  validates :rate, presence: true, numericality: { greater_than: 0 }
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :operational_date, uniqueness: { scope: %i[base_currency quote_currency] }

  before_validation :normalize_currencies

  private

  def normalize_currencies
    self.base_currency = base_currency.to_s.upcase
    self.quote_currency = quote_currency.to_s.upcase
  end
end
