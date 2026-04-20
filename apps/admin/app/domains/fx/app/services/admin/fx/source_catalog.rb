# frozen_string_literal: true

module Admin
  module Fx
    class SourceCatalog
      class << self
        def active_sources
          sync_config_sources!
          FxRateSource.where(active: true).order(:name)
        end

        def available_markets_for(source)
          return [] if source.nil?

          config = normalized_hash(source.config)
          configured_markets = Array(config["markets"]).map { |market| normalize_market(market) }.compact.uniq
          return configured_markets if configured_markets.any?

          derived_market = normalize_market([config["base_currency"], config["quote_currency"]].join)
          derived_market.present? ? [derived_market] : []
        end

        def sync_config_sources!
          configured_sources.each do |attrs|
            code = attrs["code"]
            source_type = attrs["source_type"]
            version = attrs["version"]
            next if code.blank? || source_type.blank? || version.blank?

            source = FxRateSource.find_or_initialize_by(code: code, source_type: source_type, version: version)
            source.name = attrs["name"] if attrs["name"].present?
            source.active = attrs.fetch("active", true)
            source.config = attrs.fetch("config", {})
            source.save! if source.new_record? || source.changed?
          end
        end

        private

        def configured_sources
          config = normalized_hash(Rails.configuration.x.fx_sources)
          Array(config["sources"]).map { |attrs| normalized_hash(attrs) }
        end

        def normalized_hash(value)
          return {} unless value.is_a?(Hash)

          value.each_with_object({}) do |(key, val), hash|
            hash[key.to_s] = val
          end
        end

        def normalize_market(value)
          normalized = value.to_s.upcase.gsub(/[^A-Z]/, "")
          normalized.presence
        end
      end
    end
  end
end
