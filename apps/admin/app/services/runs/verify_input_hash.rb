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

      normalized["trades"] = @sorter.sort(normalized.fetch("trades", []))
      normalized
    end

    def deep_copy(data)
      JSON.parse(JSON.generate(data))
    end
  end
end
