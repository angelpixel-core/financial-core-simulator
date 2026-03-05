if defined?(Lookbook)
  Rails.application.configure do
    config.lookbook.preview_paths = [ Rails.root.join("lookbook/previews") ]
    config.lookbook.project_name = "Financial Core Simulator Admin UI"
  end
end
