# frozen_string_literal: true

class FxRateSource < ApplicationRecord
  SOURCE_TYPES = %w[api manual file].freeze

  has_many :fx_rate_ingestions, foreign_key: :source_id, dependent: :restrict_with_exception
  has_many :fx_rate_lineages, foreign_key: :source_id, dependent: :restrict_with_exception
  has_many :fx_daily_rates, foreign_key: :source_id, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :code, presence: true
  validates :source_type, presence: true, inclusion: {in: SOURCE_TYPES}
  validates :version, presence: true
  validates :config, presence: true
end
