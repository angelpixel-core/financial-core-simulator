# frozen_string_literal: true

require_relative 'lib/fcs/version'

Gem::Specification.new do |spec|
  spec.name          = 'financial-core-simulator'
  spec.version       = FCS::VERSION
  spec.authors       = ['Angel']
  spec.summary       = 'Deterministic multi-account long-only PnL engine (spot) with audit-friendly outputs.'
  spec.description   = 'Financial Core Simulator (FCS): deterministic ledger + positions + PnL engine with canonical hashing and reproducible reports.'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.4'

  spec.files = Dir.glob(%w[
                          lib/**/*
                          bin/*
                          README*
                          LICENSE*
                        ]).select { |f| File.file?(f) }

  spec.require_paths = ['lib']

  # Runtime deps (si ya los estás usando en el core)
  spec.add_dependency 'bigdecimal'
  spec.add_dependency 'csv'
  spec.add_dependency 'zeitwerk', '~> 2.7'
end
