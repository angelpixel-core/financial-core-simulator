class Avo::Filters::RunSearchPreset < Avo::Filters::SelectFilter
  self.name = "Search preset"

  def apply(_request, query, value)
    preset = value.to_s

    case preset
    when "failed_recent"
      query.failed.order(id: :desc).limit(100)
    when "slow_recent"
      query.where.not(duration_ms: nil).where("duration_ms >= ?", 1000).order(duration_ms: :desc, id: :desc).limit(100)
    when "unverified_recent"
      query.where(verification_status: %w[unverified mismatch verification_error]).order(id: :desc).limit(100)
    else
      query
    end
  end

  def options
    {
      "Failed (recent)" => "failed_recent",
      "Slow runs (recent, >= 1000ms)" => "slow_recent",
      "Verification issues (recent)" => "unverified_recent"
    }
  end
end
