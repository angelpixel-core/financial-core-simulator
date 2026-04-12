# frozen_string_literal: true

module FCS
  class OperationResult
    attr_reader :data, :error_code, :context, :metadata

    def self.success(data: {}, metadata: {})
      new(success: true, data: data, metadata: metadata)
    end

    def self.failure(error_code:, context: {}, metadata: {})
      new(success: false, error_code: error_code, context: context, metadata: metadata)
    end

    def initialize(success:, data: {}, error_code: nil, context: {}, metadata: {})
      raise ArgumentError, "error_code is required" if !success && error_code.nil?

      @success = success
      @data = data || {}
      @error_code = error_code
      @context = context || {}
      @metadata = metadata || {}
    end

    def success?
      @success
    end

    def failure?
      !@success
    end

    def to_h
      {
        success: success?,
        data: data,
        error_code: error_code,
        context: context,
        metadata: metadata
      }
    end
  end
end
