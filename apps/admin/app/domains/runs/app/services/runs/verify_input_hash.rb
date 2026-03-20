require "json"

module Runs
  class VerifyInputHash
    def initialize(sorter: FCS::Engine::TradeSorter.new)
      @sorter = sorter
    end

    def call(run)
      raise "Run#input_json is required" if run.input_json.blank?
      raise "Run#input_hash is required" if run.input_hash.blank?

      normalized = normalize_input(run.input_json)
      canonical = FCS::Hashing::CanonicalJSON.dump(normalized)
      recomputed_hash = FCS::Hashing::SHA256.hex(canonical)
      status = recomputed_hash == run.input_hash ? :verified : :mismatch

      run.update!(
        verification_status: status,
        verified_at: Time.current,
        verification_input_hash: recomputed_hash,
        verification_error: nil
      )

      {
        status: status.to_s,
        expected_input_hash: run.input_hash,
        recomputed_input_hash: recomputed_hash,
        verified_at: run.verified_at
      }
    rescue StandardError => e
      run.update!(
        verification_status: :verification_error,
        verified_at: Time.current,
        verification_input_hash: nil,
        verification_error: e.message
      )

      {
        status: "verification_error",
        expected_input_hash: run.input_hash,
        recomputed_input_hash: nil,
        error: e.message,
        verified_at: run.verified_at
      }
    end

    private

  def normalize_input(input_json)
    normalized = deep_copy(input_json)

    fee_enabled = normalized.dig("feeModel", "enabled")
    fee_enabled = true if fee_enabled.nil?
    normalized["feeModel"] ||= {}
    normalized["feeModel"]["enabled"] = !!fee_enabled

    normalized = prepare_execution_input(normalized)
    normalize_collections_for_determinism!(normalized)
    normalized
  end

  def prepare_execution_input(input)
    return prepare_batch_input(input) unless timeline_present?(input)

    if timeline_feature_enabled?
      prepare_timeline_input(input)
    else
      raise FCS::Error.new(
        FCS::Errors::ERR_VALIDATION,
        "timeline input requires FCS_TIMELINE_ENABLED=1",
        details: { field: "timeline" }
      )
    end
  end

  def prepare_batch_input(input)
    input.delete("timeline")
    input["trades"] = @sorter.sort(input.fetch("trades"))
    input
  end

  def prepare_timeline_input(input)
    events = input.fetch("timeline").fetch("events").sort_by { |event| event.fetch("timelineSeq") }
    input["timeline"]["events"] = events
    input["trades"] = events.select { |event| event.fetch("eventType") == "TRADE_APPLIED" }
                            .map { |event| event.fetch("trade") }
    input
  end

  def normalize_collections_for_determinism!(input)
    input["accounts"] = sort_collection(input["accounts"]) { |item| item.fetch("accountId") }
    input["markets"] = sort_collection(input["markets"]) { |item| item.fetch("marketId") }

    prices = input.dig("priceSnapshot", "prices")
    return unless prices.is_a?(Array)

    input["priceSnapshot"]["prices"] = sort_collection(prices) { |item| item.fetch("marketId") }
  end

  def sort_collection(collection, &)
    return collection unless collection.is_a?(Array)

    collection.sort_by(&)
  end

  def timeline_present?(input)
    input["timeline"].is_a?(Hash) && input["timeline"]["events"].is_a?(Array)
  end

  def timeline_feature_enabled?
    ENV["FCS_TIMELINE_ENABLED"] == "1"
  end

    def deep_copy(data)
      JSON.parse(JSON.generate(data))
    end
  end
end
