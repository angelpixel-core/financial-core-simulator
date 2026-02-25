# frozen_string_literal: true

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "fcs"            => "FCS",
  "canonical_json" => "CanonicalJSON",
  "sha256"         => "SHA256",
  "fx_converter"   => "FXConverter"
)
loader.setup

module FCS
end

loader.eager_load
