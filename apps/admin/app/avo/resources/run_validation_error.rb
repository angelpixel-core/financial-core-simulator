# frozen_string_literal: true

class Avo::Resources::RunValidationError < Avo::BaseResource
  self.title = :id
  self.includes = [:run]

  def fields
    field :id, as: :id
    field :run, as: :belongs_to
    field :source, as: :text
    field :field, as: :text
    field :message, as: :textarea
    field :code, as: :text
    field :trade_id, as: :text
    field :account_id, as: :text
    field :market_id, as: :text
    field :timeline_seq, as: :number
    field :row_index, as: :number
    field :correlation_id, as: :text
    field :occurred_at, as: :date_time
    field :created_at, as: :date_time
    field :updated_at, as: :date_time
  end
end
