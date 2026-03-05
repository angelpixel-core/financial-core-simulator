if Rails.env.production? && ENV["ADMIN_UI_TOKEN"].to_s.strip.empty?
  raise "Missing required ADMIN_UI_TOKEN in production"
end
