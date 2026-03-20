# frozen_string_literal: true

module FCS
  module Engine
    # Dependency bundle used by engine components.
    #
    # @example
    #   deps = FCS::Engine::Dependencies.default
    Dependencies = Struct.new(:decimal_class, :error_class, :errors_module) do
      # @return [FCS::Engine::Dependencies]
      def self.default
        new(FCS::Types::Decimal18, FCS::Error, FCS::Errors)
      end
    end
  end
end
