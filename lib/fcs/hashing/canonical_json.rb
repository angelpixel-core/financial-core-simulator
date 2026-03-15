# frozen_string_literal: true

require "json"

module FCS
  module Hashing
    # Generates deterministic JSON for hashing.
    module CanonicalJSON
      module_function

      # Determinista: ordena claves, normaliza hashes/arrays, genera JSON estable.
      # NOTA: no intenta normalizar floats (no deberían existir en input).
      def dump(obj)
        JSON.generate(normalize(obj))
      end

      def normalize(obj)
        case obj
        when Hash
          obj.keys.sort.each_with_object({}) do |k, acc|
            acc[k] = normalize(obj.fetch(k))
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
