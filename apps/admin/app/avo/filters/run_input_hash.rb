class Avo::Filters::RunInputHash < Avo::Filters::TextFilter
  self.name = "Input hash"
  self.button_label = "Filter by input hash"

  def apply(_request, query, value)
    return query if value.blank?

    query.where("input_hash ILIKE ?", "%#{value.strip}%")
  end
end
