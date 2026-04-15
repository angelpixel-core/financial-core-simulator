# frozen_string_literal: true

module Admin
  module Dashboard
    module Repositories
      module ActiveRecord
        class RunRepository
          def find_by_id(run_id)
            Run.find_by(id: run_id)
          end
        end
      end
    end
  end
end
