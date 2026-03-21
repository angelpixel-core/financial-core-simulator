class Admin::Ui::EmptyStateComponent < ViewComponent::Base
  def initialize(message:, title: nil, icon: nil, tone: :default)
    @title = title
    @message = message
    @icon = icon
    @tone = tone.to_sym
  end

  def tone_class
    case @tone
    when :error
      "ui-empty-state--error"
    when :loading
      "ui-empty-state--loading"
    else
      "ui-empty-state--default"
    end
  end
end
