# typed: true

module FCS
  module Currency
    extend T::Sig

    sig { params(value: T.untyped).returns(String) }
    def self.normalize(value); end

    sig { params(value: T.untyped).returns(T::Boolean) }
    def self.valid_code?(value); end
  end
end

class ApplicationRecord
end

class FxRateSource < ApplicationRecord
  extend T::Sig

  sig { returns(Integer) }
  def id; end

  sig { returns(String) }
  def code; end

  sig { returns(T::Hash[T.untyped, T.untyped]) }
  def config; end
end

module Admin
  module Fx
    module Ingestion
      class Result
        extend T::Sig

        sig { params(data: T::Hash[T.untyped, T.untyped], metadata: T::Hash[T.untyped, T.untyped]).returns(Result) }
        def self.success(data: {}, metadata: {}); end

        sig { params(error_code: String, context: T::Hash[T.untyped, T.untyped], metadata: T::Hash[T.untyped, T.untyped]).returns(Result) }
        def self.failure(error_code:, context: {}, metadata: {}); end
      end
    end
  end
end
