# typed: ignore
# frozen_string_literal: true

module Admin
  module Fx
    module Ingestion
      module Validators
        class BcraContract < Dry::Validation::Contract
          schema do
            required(:status).filled(:integer)
            required(:metadata).hash do
              required(:resultset).hash do
                required(:count).filled(:integer)
                required(:offset).filled(:integer)
                required(:limit).filled(:integer)
              end
            end
            required(:results).array(:hash) do
              required(:fecha).filled(:string)
              required(:detalle).array(:hash) do
                required(:codigoMoneda).filled(:string)
                required(:tipoCotizacion).filled(:string)
                optional(:descripcion).maybe(:string)
                optional(:tipoPase).maybe(:string)
              end
            end
          end
        end
      end
    end
  end
end
