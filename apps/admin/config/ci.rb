# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  # Mandatory release-gate baseline (clear fail-fast semantics)
  step "Gate: Admin test regression", "bundle exec rspec -Ispec spec"
  step "Gate: Style (RuboCop)", "bin/rubocop"

  step "Gate: Security - Gem audit", "bin/bundler-audit"
  step "Gate: Security - Importmap vulnerability audit", "bin/importmap audit"
  step "Gate: Security - Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  if ENV["ENABLE_COVERAGE_GATE"] == "1"
    step "Gate: Coverage report", "ADMIN_COVERAGE=1 ADMIN_COVERAGE_MODE=report ADMIN_COVERAGE_DIR=coverage/admin bundle exec rspec -Ispec spec"

    if ENV["ENFORCE_COVERAGE_GATE"] == "1"
      threshold = ENV.fetch("ADMIN_COVERAGE_MIN", "80")
      step "Gate: Coverage threshold", "ADMIN_COVERAGE=1 ADMIN_COVERAGE_MODE=enforce ADMIN_COVERAGE_MIN=#{threshold} ADMIN_COVERAGE_DIR=coverage/admin bundle exec rspec -Ispec spec"
    end
  end


  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
