# frozen_string_literal: true

class Avo::Filters::RunStatus < Avo::Filters::SelectFilter
  self.name = "Status"

  def apply(_request, query, value)
    return query if value.blank?
    query.where(status: ::Run.statuses.fetch(value))
  end

  def options
    ::Run.statuses.keys.index_with(&:to_s)
  end
end
