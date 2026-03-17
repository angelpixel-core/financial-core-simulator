# frozen_string_literal: true

module FCS
  module Engine
    Dependencies = Struct.new(:decimal_class, :error_class, :errors_module) do
      def self.default
        new(FCS::Types::Decimal18, FCS::Error, FCS::Errors)
      end
    end
  end
end
