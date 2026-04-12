# frozen_string_literal: true

class FxRateIngestion < ApplicationRecord
  STATUSES = %w[pending running success failed].freeze

  belongs_to :source, class_name: "FxRateSource"
  has_many :fx_rate_lineages, foreign_key: :ingestion_id, dependent: :restrict_with_exception

  validates :status, presence: true, inclusion: {in: STATUSES}
  validates :correlation_id, presence: true
end
