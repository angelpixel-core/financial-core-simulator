module Release
  class GateDecision
    REQUIRED_RESULTS = {
      pre_demo: %i[test_admin lint_admin security],
      pre_production: %i[test_admin lint_admin security]
    }.freeze

    def self.evaluate(gate_type:, command_results:, lint_debt_policy: nil)
      required = REQUIRED_RESULTS.fetch(gate_type.to_sym)
      blockers = required.each_with_object([]) do |key, list|
        next if command_results.fetch(key, :fail).to_sym == :pass
        next if key == :lint_admin && lint_debt_accepted_with_metadata?(lint_debt_policy)

        list << key.to_s
      end

      if lint_debt_policy&.fetch(:accepted, false) && !lint_debt_metadata_present?(lint_debt_policy)
        blockers << "lint_debt_policy_metadata_missing"
      end

      {
        decision: blockers.empty? ? "GO" : "NO-GO",
        blockers: blockers
      }
    rescue KeyError
      raise ArgumentError, "Unsupported gate type: #{gate_type}"
    end

    def self.lint_debt_accepted_with_metadata?(lint_debt_policy)
      return false unless lint_debt_policy&.fetch(:accepted, false)

      lint_debt_metadata_present?(lint_debt_policy)
    end

    def self.lint_debt_metadata_present?(lint_debt_policy)
      required_fields = %i[owner expiry scope]
      required_fields.all? { |field| lint_debt_policy[field].to_s.strip != "" }
    end

    private_class_method :lint_debt_accepted_with_metadata?, :lint_debt_metadata_present?
  end
end
