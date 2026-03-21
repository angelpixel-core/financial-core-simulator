# frozen_string_literal: true

module FCS
  module Projector
    # Applies events to projections and builds composite read models.
    #
    # @example
    #   store = FCS::Projector::ProjectionStore.new(projections: projections)
    #   store.apply!(%w[overview], event)
    class ProjectionStore
      # @param projections [Hash{String => #apply!, #read_model}]
      def initialize(projections:)
        @projections = normalize_projections!(projections)
      end

      # Applies an event to the selected projections.
      #
      # @param projection_keys [Array<String>]
      # @param event [Hash]
      # @return [true]
      # @raise [FCS::Error]
      def apply!(projection_keys, event)
        validate_projection_keys!(projection_keys)

        projection_keys.each do |projection_key|
          projection_for(projection_key).apply!(event)
        end

        true
      end

      # Returns the merged read model across projections.
      #
      # @return [Hash]
      def read_model
        @projections.values.each_with_object({}) do |projection, composite|
          composite.merge!(projection.read_model)
        end
      end

      private

      def normalize_projections!(projections)
        unless projections.is_a?(Hash) && !projections.empty?
          raise_invalid!("projection store requires a non-empty projections hash", field: "projectionStore")
        end

        projections.each_with_object({}) do |(projection_key, projection), normalized|
          validate_non_empty_string!(projection_key, field: "projectionStore.projections.key")
          validate_projection_interface!(projection, projection_key)
          normalized[projection_key] = projection
        end
      end

      def validate_projection_keys!(projection_keys)
        return if projection_keys.is_a?(Array) && !projection_keys.empty?

        raise_invalid!("projection keys must be a non-empty array", field: "projectionStore.projectionKeys")
      end

      def projection_for(projection_key)
        projection = @projections.fetch(projection_key, nil)
        return projection unless projection.nil?

        raise_invalid!("projection key is not registered", field: "projectionStore.projections.#{projection_key}")
      end

      def validate_projection_interface!(projection, projection_key)
        return if projection.respond_to?(:apply!) && projection.respond_to?(:read_model)

        raise_invalid!("projection must implement apply! and read_model",
          field: "projectionStore.projections.#{projection_key}")
      end

      def validate_non_empty_string!(value, field:)
        return if value.is_a?(String) && !value.strip.empty?

        raise_invalid!("projection store field must be a non-empty string", field: field)
      end

      def raise_invalid!(message, field:)
        raise FCS::Error.new(FCS::Errors::ERR_VALIDATION, message, details: {field: field})
      end
    end
  end
end
