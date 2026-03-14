if defined?(RailsLiveReload)
  RailsLiveReload.configure do |config|
    config.watch(%r{app/views/.+\.(erb|haml|slim)$}, reload: :always)
    config.watch(%r{app/components/.+\.(erb|haml|slim)$}, reload: :always)
  end
end
