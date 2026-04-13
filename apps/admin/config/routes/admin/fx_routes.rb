# frozen_string_literal: true

module Admin
  module FxRoutes
    def self.extended(router)
      router.instance_exec do
        namespace :fx do
          resources :daily_rates, only: %i[create update destroy] do
            post :carry_forward, on: :collection
            patch :current, on: :collection
          end
          resources :rate_uploads, only: :create do
            get :template, on: :collection
          end
          resources :ingestions, only: :index do
            post :sync, on: :collection
          end
          resource :reporting_settings, only: %i[update]
          resources :history, only: :index
        end
      end
    end
  end
end
