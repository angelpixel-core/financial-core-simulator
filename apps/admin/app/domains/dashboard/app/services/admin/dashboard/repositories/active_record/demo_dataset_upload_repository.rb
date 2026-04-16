# frozen_string_literal: true

module Admin
  module Dashboard
    module Repositories
      module ActiveRecord
        class DemoDatasetUploadRepository
          def latest
            DemoDatasetUpload.latest
          end
        end
      end
    end
  end
end
