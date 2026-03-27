class Admin::Ui::WorkspaceWidgetComponent < ViewComponent::Base
  def initialize(title:, cta_path: nil, cta_label: nil, updated_at: nil, actions_label: nil, state: :default, body_class: nil,
    loading_message: I18n.t("admin.ui.workspace_widget.loading_message"),
    empty_message: I18n.t("admin.ui.workspace_widget.empty_message"),
    error_message: I18n.t("admin.ui.workspace_widget.error_message"))
    @title = title
    @cta_path = cta_path
    @cta_label = cta_label
    @updated_at = updated_at
    @actions_label = actions_label
    @state = state.to_sym
    @body_class = body_class
    @loading_message = loading_message
    @empty_message = empty_message
    @error_message = error_message
  end

  def actions_label
    @actions_label.presence || I18n.t("admin.ui.workspace_widget.actions_label", title: @title)
  end

  def render_state?
    loading? || empty? || error?
  end

  def loading?
    @state == :loading
  end

  def empty?
    @state == :empty
  end

  def error?
    @state == :error
  end

  def state_tone
    return :loading if loading?
    return :error if error?

    :default
  end

  def state_message
    return @loading_message if loading?
    return @error_message if error?

    @empty_message
  end
end
