class Admin::Ui::WorkspaceTrendChartComponent < ViewComponent::Base
  def initialize(points:, detail: false)
    @points = points
    @detail = detail
  end

  def trend_class
    @detail ? "trend-chart trend-chart--detail" : "trend-chart"
  end

  def title_value
    @detail ? "Runs trend detail" : nil
  end

  def max_trend
    [ @points.map { |point| point[:count] }.max.to_i, 1 ].max
  end
end
