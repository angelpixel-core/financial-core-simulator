# frozen_string_literal: true

module Avo
  module LegacyResourceRoutes
    def self.extended(router)
      router.instance_exec do
        scope :avo do
          scope :resources do
            scope 'runs/:id' do
              concerns :run_artifact_redirects
            end
          end
        end
      end
    end
  end
end
