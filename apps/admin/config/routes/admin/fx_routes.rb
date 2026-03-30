# frozen_string_literal: true

module Admin
  module FxRoutes
    def self.extended(router)
      router.instance_exec do
        namespace :fx do
          resources :daily_rates, only: %i[create] do
            post :carry_forward, on: :collection
          end
          resource :reporting_settings, only: %i[update]
        end
      end
    end
  end
end
