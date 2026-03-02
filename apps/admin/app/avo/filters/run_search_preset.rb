class Avo::Filters::RunSearchPreset < Avo::Filters::SelectFilter
  self.name = "Search preset"

  def apply(_request, query, value)
    case value
    when "failed_recent"
      query.failed.order(id: :desc).limit(100)
    when "slow_recent"
      query.where.not(duration_ms: nil).where("duration_ms >= ?", 1000).order(duration_ms: :desc)
    when "unverified_recent"
      query.where(verification_status: "unverified").order(id: :desc).limit(100)
    else
      query
    end
  end

  def options
    {
      "Failed (recent)" => "failed_recent",
      "Slow runs (>= 1000ms)" => "slow_recent",
      "Unverified (recent)" => "unverified_recent"
    }
  end
end
