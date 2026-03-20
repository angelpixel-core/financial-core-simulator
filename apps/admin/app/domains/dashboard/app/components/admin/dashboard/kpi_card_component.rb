class Admin::Dashboard::KpiCardComponent < ViewComponent::Base
  def initialize(title:, value:, subtitle: nil, counter: nil)
    @title = title
    @value = value
    @subtitle = subtitle
    @counter = counter
  end
end
