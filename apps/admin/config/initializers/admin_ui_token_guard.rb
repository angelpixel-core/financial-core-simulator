if Rails.env.production? && ENV["ADMIN_UI_TOKEN"].to_s.strip.empty?
  raise "ADMIN_UI_TOKEN must be set in production"
end
