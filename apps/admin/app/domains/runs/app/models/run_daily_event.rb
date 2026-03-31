# frozen_string_literal: true

class RunDailyEvent < ApplicationRecord
  belongs_to :run_snapshot

  validates :run_snapshot_id, presence: true
  validates :event_type, presence: true
  validates :payload, presence: true
end
