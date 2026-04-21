# typed: ignore
# frozen_string_literal: true

module Admin
  module Fx
    module Ingestion
      module Validators
        class BinanceContract < Dry::Validation::Contract
          schema do
            required(:status).filled(:integer)
            required(:metadata).hash do
              required(:resultset).hash do
                required(:count).filled(:integer)
                required(:offset).filled(:integer)
                required(:limit).filled(:integer)
              end
              required(:market).filled(:string)
              required(:interval).filled(:string)
            end
            required(:results).array(:hash) do
              required(:open_time).filled(:integer)
              required(:close).filled(:string)
              required(:close_time).filled(:integer)
            end
          end
        end
      end
    end
  end
end
