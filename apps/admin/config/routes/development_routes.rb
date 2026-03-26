# frozen_string_literal: true

module DevelopmentRoutes
  def self.extended(router)
    router.instance_exec do
      mount Lookbook::Engine, at: "/lookbook"
    end
  end
end
