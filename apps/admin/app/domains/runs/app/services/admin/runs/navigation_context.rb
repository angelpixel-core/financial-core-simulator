module Admin
  module Runs
    class NavigationContext
      CONTEXT_KEYS = %w[selected_run run_status validation_status date_range correlation_id].freeze
      SESSION_KEY = 'admin.runs.navigation_context'

      def self.capture(params:, run: nil)
        source = if params.respond_to?(:to_unsafe_h)
                   params.to_unsafe_h
                 elsif params.respond_to?(:to_h)
                   params.to_h
                 else
                   params
                 end

        context = normalize_hash(source)
        context['selected_run'] ||= run&.id&.to_s
        context.compact
      end

      def self.normalize_hash(value)
        hash = value.is_a?(Hash) ? value : {}
        hash.each_with_object({}) do |(key, current), normalized|
          next unless CONTEXT_KEYS.include?(key.to_s)

          cleaned = current.to_s.strip
          normalized[key.to_s] = cleaned unless cleaned.empty?
        end
      end

      def initialize(params:, session:)
        @params = params
        @session = session
      end

      def resolve
        persisted = normalize_hash(@session[SESSION_KEY])
        incoming = self.class.capture(params: @params)
        cleared_keys = explicitly_cleared_keys

        return persisted if incoming.empty? && cleared_keys.empty?

        merged = persisted.merge(incoming)
        cleared_keys.each { |key| merged.delete(key) }
        @session[SESSION_KEY] = merged
        merged
      end

      private

      def normalize_hash(value)
        self.class.normalize_hash(value)
      end

      def explicitly_cleared_keys
        raw = raw_params_hash

        CONTEXT_KEYS.each_with_object([]) do |key, cleared|
          value = fetch_raw_value(raw, key)
          next if value.nil?

          cleared << key if value.to_s.strip.empty?
        end
      end

      def raw_params_hash
        if @params.respond_to?(:to_unsafe_h)
          @params.to_unsafe_h
        elsif @params.respond_to?(:to_h)
          @params.to_h
        else
          @params
        end
      end

      def fetch_raw_value(raw, key)
        return nil unless raw.is_a?(Hash)

        raw[key] || raw[key.to_sym]
      end
    end
  end
end
