# typed: ignore
# frozen_string_literal: true

module Admin
  module Fx
    module Ingestion
      class AdapterRegistry
        def self.build(source)
          return nil if source.nil?

          case source.code
          when "BCRA"
            Adapters::BcraAdapter.new(source: source)
          end
        end
      end
    end
  end
end
