class Avo::Filters::RunGlobalSearch < Avo::Filters::TextFilter
  self.name = "Global search"
  self.button_label = "Search hash, UUID, errors"

  def apply(_request, query, value)
    return query if value.blank?

    pattern = "%#{value.strip}%"
    query.where(
      "run_uuid ILIKE :q OR input_hash ILIKE :q OR error_code ILIKE :q OR error_message ILIKE :q",
      q: pattern
    )
  end
end
