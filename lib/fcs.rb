# frozen_string_literal: true

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("fcs" => "FCS")
loader.setup

module FCS
end

loader.eager_load
