# frozen_string_literal: true

module Admin
  module DemoDataset
    module Repositories
      module ActiveRecord
        class RunRepository
          def create_with_input!(input_json:)
            Run.create!(input_json: input_json)
          end

          def delete_all!
            Run.delete_all
          end
        end
      end
    end
  end
end
