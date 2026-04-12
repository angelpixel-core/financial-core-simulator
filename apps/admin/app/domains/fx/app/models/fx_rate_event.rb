# frozen_string_literal: true

class FxRateEvent < ApplicationRecord
  validates :event_type, presence: true
end
