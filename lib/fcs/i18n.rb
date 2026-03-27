# frozen_string_literal: true

require 'i18n'
require 'i18n/backend/fallbacks'

module FCS
  module I18n
    DEFAULT_LOCALE = :en
    SUPPORTED_LOCALES = %i[en es].freeze

    def self.load_translations!
      locales_path = File.join(__dir__, 'locales', '**', '*.yml')
      ::I18n::Backend::Simple.include(::I18n::Backend::Fallbacks)
      ::I18n.load_path |= Dir[locales_path]
      ::I18n.available_locales = SUPPORTED_LOCALES
      ::I18n.default_locale = DEFAULT_LOCALE
      ::I18n.fallbacks = ::I18n::Locale::Fallbacks.new(
        en: [:en],
        es: %i[es en]
      )
    end

    def self.configure_locale(locale = ENV.fetch('FCS_LOCALE', DEFAULT_LOCALE))
      selected = locale.to_s.tr('-', '_')
      symbol = selected.to_sym
      ::I18n.locale = SUPPORTED_LOCALES.include?(symbol) ? symbol : DEFAULT_LOCALE
    end
  end
end
