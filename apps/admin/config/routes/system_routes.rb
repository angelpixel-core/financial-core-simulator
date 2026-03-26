# frozen_string_literal: true

module SystemRoutes
  def self.extended(router)
    router.instance_exec do
      get "up" => "rails/health#show", :as => :rails_health_check
    end
  end
end
