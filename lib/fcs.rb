# frozen_string_literal: true

require_relative 'fcs/version'

require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  'fcs' => 'FCS',
  'canonical_json' => 'CanonicalJSON',
  'sha256' => 'SHA256',
  'fx_converter' => 'FXConverter',
  'csv_pnl' => 'CsvPnL'
)
loader.ignore("#{__dir__}/financial")
loader.setup

module FCS
end

loader.eager_load
