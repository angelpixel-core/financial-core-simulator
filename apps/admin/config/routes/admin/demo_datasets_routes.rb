# frozen_string_literal: true

module Admin
  module DemoDatasetsRoutes
    def self.extended(router)
      router.instance_exec do
        post "demo-datasets", to: "demo/datasets#create", as: :demo_datasets
        post "demo-datasets/reset", to: "demo/datasets#reset", as: :demo_datasets_reset
        post "demo-datasets/preview", to: "demo/datasets#preview", as: :demo_datasets_preview
      end
    end
  end
end
