# frozen_string_literal: true

require "i18n"

module FCS
  module I18n
    DEFAULT_LOCALE = :en
    SUPPORTED_LOCALES = %i[en es].freeze

    def self.load_translations!
      locales_path = File.join(__dir__, "locales", "*.yml")
      ::I18n.load_path |= Dir[locales_path]
      ::I18n.available_locales = SUPPORTED_LOCALES
      ::I18n.default_locale = DEFAULT_LOCALE
      ::I18n.fallbacks = true
    end

    def self.configure_locale(locale = ENV.fetch("FCS_LOCALE", DEFAULT_LOCALE))
      selected = locale.to_s.tr("-", "_")
      symbol = selected.to_sym
      ::I18n.locale = SUPPORTED_LOCALES.include?(symbol) ? symbol : DEFAULT_LOCALE
    end
  end
end
