class Admin::Ui::EmptyStateComponentPreview < ViewComponent::Preview
  def default
    render Admin::Ui::EmptyStateComponent.new(
      title: "No top accounts yet",
      message: "Run at least one succeeded simulation to populate account totals.",
      icon: "-"
    )
  end

  def loading
    render Admin::Ui::EmptyStateComponent.new(
      title: "Loading",
      message: "Preparing dashboard data.",
      icon: "...",
      tone: :loading
    )
  end

  def empty
    render Admin::Ui::EmptyStateComponent.new(
      message: "No ingestion validation errors."
    )
  end

  def error
    render Admin::Ui::EmptyStateComponent.new(
      title: "Data unavailable",
      message: "The dashboard source is temporarily unavailable. Try again in a few seconds.",
      icon: "!",
      tone: :error
    )
  end
end
