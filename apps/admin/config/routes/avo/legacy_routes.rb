# frozen_string_literal: true

module Avo
  module LegacyRoutes
    def self.extended(router)
      router.instance_exec do
        scope :avo do
          get '/', to: redirect('/admin'), as: :legacy_avo_root
          get '/*path', to: redirect('/admin/%{path}'), as: :legacy_avo_catch_all
        end
      end
    end
  end
end
