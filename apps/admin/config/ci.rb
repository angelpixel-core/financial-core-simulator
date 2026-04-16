# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Gate: Contract boundaries (ports + auth)",
    "bundle exec rspec -Ispec spec/contracts/ports spec/contracts/access_control"
  step "Gate: Cross-context smoke (request/system)",
    "bundle exec rspec -Ispec spec/requests/admin/cross_context_smoke_spec.rb spec/system/admin/cross_context_smoke_spec.rb"
  step "Gate: Boundary matrix (architecture)",
    "bundle exec rspec -Ispec spec/architecture/controller_domain_api_enforcement_spec.rb spec/architecture/packwerk_boundary_matrix_spec.rb"
  step "Gate: Packwerk boundaries", "bundle exec packwerk check"

  # Mandatory release-gate baseline (clear fail-fast semantics)
  step "Gate: Admin test regression", "bundle exec rspec -Ispec spec"
  step "Gate: Style (StandardRB)", "bundle exec standardrb"

  step "Gate: Security - Gem audit", "bin/bundler-audit"
  step "Gate: Security - Importmap vulnerability audit", "bin/importmap audit"
  step "Gate: Security - Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  if ENV["ENABLE_COVERAGE_GATE"] == "1"
    step "Gate: Coverage report",
      [
        "ADMIN_COVERAGE=1",
        "ADMIN_COVERAGE_MODE=report",
        "ADMIN_COVERAGE_DIR=coverage/admin",
        "bundle exec rspec -Ispec spec"
      ].join(" ")

    if ENV["ENFORCE_COVERAGE_GATE"] == "1"
      threshold = ENV.fetch("ADMIN_COVERAGE_MIN", "80")
      step "Gate: Coverage threshold",
        [
          "ADMIN_COVERAGE=1",
          "ADMIN_COVERAGE_MODE=enforce",
          "ADMIN_COVERAGE_MIN=#{threshold}",
          "ADMIN_COVERAGE_DIR=coverage/admin",
          "bundle exec rspec -Ispec spec"
        ].join(" ")
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
