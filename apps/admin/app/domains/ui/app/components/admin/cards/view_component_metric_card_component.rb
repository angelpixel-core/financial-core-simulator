class Admin::Cards::ViewComponentMetricCardComponent < ViewComponent::Base
  def initialize(title:, value:, info:)
    @title = title
    @value = value
    @info = info
  end
end
