# frozen_string_literal: true

module Admin
  module DocsRoutes
    def self.extended(router)
      router.instance_exec do
        scope :docs do
          get "/", to: "docs#index", as: :docs
          get ":section", to: "docs#show", as: :docs_section
        end
      end
    end
  end
end
