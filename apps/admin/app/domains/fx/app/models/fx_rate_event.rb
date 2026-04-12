# frozen_string_literal: true

class FxRateEvent < ApplicationRecord
  validates :event_id, presence: true
  validates :event_type, presence: true
end
