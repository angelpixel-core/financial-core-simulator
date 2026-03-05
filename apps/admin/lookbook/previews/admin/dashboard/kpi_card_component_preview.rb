class Admin::Dashboard::KpiCardComponentPreview < ViewComponent::Preview
  def default
    render Admin::Dashboard::KpiCardComponent.new(
      title: "Success rate (last 50)",
      value: "94%",
      subtitle: "Succeeded vs total runs"
    )
  end

  def loading
    render Admin::Dashboard::KpiCardComponent.new(
      title: "Success rate (last 50)",
      value: "...",
      subtitle: "Loading KPI"
    )
  end

  def empty
    render Admin::Dashboard::KpiCardComponent.new(
      title: "Success rate (last 50)",
      value: "N/A",
      subtitle: "No succeeded runs yet"
    )
  end

  def error
    render Admin::Dashboard::KpiCardComponent.new(
      title: "Success rate (last 50)",
      value: "N/A",
      subtitle: "Could not compute from recent runs"
    )
  end
end
