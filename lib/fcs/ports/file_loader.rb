# frozen_string_literal: true

module FCS
  module Ports
    class FileLoader
      def load(file_path:, **options)
        raise NotImplementedError, "#{self.class} must implement #load"
      end
    end
  end
end
