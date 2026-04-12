# frozen_string_literal: true

class Avo::Resources::FxRateSource < Avo::BaseResource
  self.title = :name
  self.includes = []

  def fields
    field :id, as: :id
    field :name, as: :text
    field :code, as: :text
    field :source_type, as: :select, options: FxRateSource::SOURCE_TYPES
    field :version, as: :text
    field :active, as: :boolean
    field :config, as: :key_value
    field :created_at, as: :date_time
    field :updated_at, as: :date_time
  end
end
