# frozen_string_literal: true

require "rails"
require "rails/application"
require "active_support"

module PackwerkLib
  class Application < Rails::Application
    config.root = Pathname.new(__dir__).join("..").expand_path
    config.eager_load = false
    config.autoload_paths << config.root.join("fcs").to_s
    config.eager_load_paths << config.root.join("fcs").to_s
    ActiveSupport::Inflector.inflections(:en) do |inflect|
      inflect.acronym "FCS"
    end
  end
end
