# frozen_string_literal: true

require "digest"

module FCS
  module Hashing
    module SHA256
      module_function

      def hex(str)
        Digest::SHA256.hexdigest(str)
      end
    end
  end
end
