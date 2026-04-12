# frozen_string_literal: true

class ReportingSetting < ApplicationRecord
  DEFAULT_SINGLETON_KEY = "reporting"
  DEFAULT_REPORTING_CURRENCY = "USD"
  CURRENCY_CODE_FORMAT = FCS::Currency::CODE_FORMAT

  validates :singleton_key, presence: true, inclusion: {in: [DEFAULT_SINGLETON_KEY]}
  validates :reporting_currency, presence: true, format: {with: CURRENCY_CODE_FORMAT},
    inclusion: {in: ->(_record) { FCS::Currency.supported_fiat }}
  validates :singleton_key, uniqueness: true

  before_validation :set_defaults
  before_validation :normalize_currency

  def self.current
    find_or_create_by!(singleton_key: DEFAULT_SINGLETON_KEY) do |setting|
      setting.reporting_currency = DEFAULT_REPORTING_CURRENCY
    end
  end

  def self.supported_currencies
    FCS::Currency.supported_fiat
  end

  private

  def set_defaults
    self.singleton_key = DEFAULT_SINGLETON_KEY if singleton_key.blank?
    self.reporting_currency = DEFAULT_REPORTING_CURRENCY if reporting_currency.blank?
  end

  def normalize_currency
    self.reporting_currency = reporting_currency.to_s.upcase
  end
end
