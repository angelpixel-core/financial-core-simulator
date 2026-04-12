# frozen_string_literal: true

module FCS
  class Currency
    CODE_FORMAT = /\A[A-Z]{3}\z/
    DEFAULT_SUPPORTED_FIAT = %w[USD ARS].freeze
    DEFAULT_SUPPORTED_CRYPTO = %w[BTC ETH].freeze

    def self.supported_fiat
      normalize_list(currency_config[:supported_fiat], DEFAULT_SUPPORTED_FIAT)
    end

    def self.supported_crypto
      normalize_list(currency_config[:supported_crypto], DEFAULT_SUPPORTED_CRYPTO)
    end

    def self.supported_codes
      (supported_fiat + supported_crypto).uniq
    end

    def self.normalize(code)
      code.to_s.upcase
    end

    def self.valid_code?(code)
      CODE_FORMAT.match?(normalize(code))
    end

    def self.supported?(code)
      supported_codes.include?(normalize(code))
    end

    def self.fiat?(code)
      supported_fiat.include?(normalize(code))
    end

    def self.crypto?(code)
      supported_crypto.include?(normalize(code))
    end

    def self.normalize_list(value, fallback)
      Array(value.presence || fallback).map { |item| normalize(item) }.uniq
    end

    def self.currency_config
      config = Rails.configuration.x.currency || {}
      config = config.to_h if config.respond_to?(:to_h)
      config.respond_to?(:with_indifferent_access) ? config.with_indifferent_access : config
    end
  end
end
