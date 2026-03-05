class Admin::Ui::EmptyStateComponent < ViewComponent::Base
  def initialize(title: nil, message:, icon: nil)
    @title = title
    @message = message
    @icon = icon
  end
end
