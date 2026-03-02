class Avo::Filters::RunUuid < Avo::Filters::TextFilter
  self.name = "Run UUID"
  self.button_label = "Filter by run UUID"

  def apply(_request, query, value)
    return query if value.blank?

    query.where("run_uuid ILIKE ?", "%#{value.strip}%")
  end
end
