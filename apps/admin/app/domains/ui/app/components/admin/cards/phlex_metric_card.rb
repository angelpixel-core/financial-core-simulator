class Admin::Cards::PhlexMetricCard < Phlex::HTML
  def initialize(title:, value:, info:)
    @title = title
    @value = value
    @info = info
  end

  def view_template
    article(style: "border:1px solid #d1d5db; border-radius:8px; padding:12px; margin:8px 0;") do
      p(style: "margin:0; font-size:12px; color:#4b5563;") { "Phlex" }
      h3(style: "margin:4px 0 8px 0;") { @title }
      p(style: "margin:0; font-size:24px; font-weight:700;") { @value }
      p(style: "margin:8px 0 0 0; color:#4b5563;") { @info }
    end
  end
end
