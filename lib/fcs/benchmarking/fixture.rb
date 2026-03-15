# frozen_string_literal: true

require "json"

module FCS
  module Benchmarking
    class Fixture
      attr_reader :schema_version, :fixture_version, :trades, :accounts, :markets, :valuation_timestamp

      def self.load(path:)
        raw = File.read(path)
        data = JSON.parse(raw)

        fixture = new(
          schema_version: data.fetch("schemaVersion"),
          fixture_version: data.fetch("fixtureVersion"),
          trades: data.fetch("trades"),
          accounts: data.fetch("accounts"),
          markets: data.fetch("markets"),
          valuation_timestamp: data.fetch("valuationTimestamp")
        )

        fixture.validate!(path: path)
        fixture
      rescue Errno::ENOENT
        raise FCS::Error.new(FCS::Errors::ERR_INVALID_INPUT, "Fixture file not found", details: { path: path })
      rescue Errno::EACCES
        raise FCS::Error.new(FCS::Errors::ERR_INVALID_INPUT, "Fixture file is not readable", details: { path: path })
      rescue JSON::ParserError
        raise FCS::Error.new(
          FCS::Errors::ERR_INVALID_INPUT,
          "Fixture JSON is invalid",
          details: { path: path, errorClass: "JSON::ParserError", errorCode: "INVALID_JSON_SYNTAX" }
        )
      rescue KeyError => e
        raise FCS::Error.new(
          FCS::Errors::ERR_INVALID_INPUT,
          "Fixture missing required field",
          details: { path: path, field: e.message }
        )
      end

      def initialize(schema_version:, fixture_version:, trades:, accounts:, markets:, valuation_timestamp:)
        @schema_version = schema_version
        @fixture_version = fixture_version
        @trades = trades
        @accounts = accounts
        @markets = markets
        @valuation_timestamp = valuation_timestamp
      end

      def to_h
        {
          "schema_version" => schema_version,
          "fixture_version" => fixture_version,
          "trades" => trades,
          "accounts" => accounts,
          "markets" => markets,
          "valuation_timestamp" => valuation_timestamp
        }
      end

      def validate!(path:)
        validate_integer!("trades", trades, path: path)
        validate_integer!("accounts", accounts, path: path)
        validate_integer!("markets", markets, path: path)

        if trades < 100_000
          raise FCS::Error.new(
            FCS::Errors::ERR_INVALID_INPUT,
            "Fixture must define at least 100,000 trades",
            details: { path: path, trades: trades }
          )
        end

        unless schema_version.is_a?(String) && !schema_version.strip.empty?
          raise FCS::Error.new(
            FCS::Errors::ERR_INVALID_INPUT,
            "Fixture schemaVersion must be a non-empty string",
            details: { path: path, schemaVersion: schema_version }
          )
        end

        return if valuation_timestamp.is_a?(String) && !valuation_timestamp.strip.empty?

        raise FCS::Error.new(
          FCS::Errors::ERR_INVALID_INPUT,
          "Fixture valuationTimestamp must be a non-empty string",
          details: { path: path, valuationTimestamp: valuation_timestamp }
        )
      end

      private

      def validate_integer!(field, value, path:)
        return if value.is_a?(Integer) && value.positive?

        raise FCS::Error.new(
          FCS::Errors::ERR_INVALID_INPUT,
          "Fixture #{field} must be a positive integer",
          details: { path: path, field: field, value: value }
        )
      end
    end
  end
end
