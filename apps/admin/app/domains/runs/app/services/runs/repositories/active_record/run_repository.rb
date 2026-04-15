# frozen_string_literal: true

module Runs
  module Repositories
    module ActiveRecord
      class RunRepository < FCS::Ports::RunRepository
        def save_run!(run_id:, attributes:)
          run = find_run(run_id: run_id)
          run.update!(attributes)
          run
        end

        def find_run(run_id:)
          Run.find(run_id)
        end
      end
    end
  end
end
