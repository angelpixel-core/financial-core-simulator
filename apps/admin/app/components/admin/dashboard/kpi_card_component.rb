class Admin::Dashboard::KpiCardComponent < ViewComponent::Base
  def initialize(title:, value:, subtitle: nil)
    @title = title
    @value = value
    @subtitle = subtitle
  end
end
