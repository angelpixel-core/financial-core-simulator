# frozen_string_literal: true

class FxRateLineage < ApplicationRecord
  STATUSES = %w[pending valid invalid persisted skipped failed].freeze

  belongs_to :ingestion, class_name: "FxRateIngestion"
  belongs_to :source, class_name: "FxRateSource"

  validates :operational_date, presence: true
  validates :base_currency, presence: true
  validates :quote_currency, presence: true
  validates :status, presence: true, inclusion: {in: STATUSES}
  validates :correlation_id, presence: true
end
