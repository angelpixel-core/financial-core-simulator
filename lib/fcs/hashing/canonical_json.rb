# frozen_string_literal: true

require "json"

module FCS
  module Hashing
    # Generates deterministic JSON for hashing.
    #
    # @example
    #   canonical = FCS::Hashing::CanonicalJSON.dump(payload)
    module CanonicalJSON
      module_function

      # Determinista: ordena claves, normaliza hashes/arrays, genera JSON estable.
      # NOTA: no intenta normalizar floats (no deberían existir en input).
      #
      # @param obj [Object]
      # @return [String]
      def dump(obj)
        JSON.generate(normalize(obj))
      end

      # @param obj [Object]
      # @return [Object]
      def normalize(obj)
        case obj
        when Hash
          obj.keys.sort.to_h do |k|
            [k, normalize(obj.fetch(k))]
          end
        when Array
          obj.map { |v| normalize(v) }
        else
          obj
        end
      end
    end
  end
end
