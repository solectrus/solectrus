# Continuous Integration configuration for Rails 8.1+
# Run using: bin/ci
#
# This replaces the previous bin/test script with Rails' new declarative CI DSL.
# All checks are run sequentially, and the process exits on the first failure.

CI.run do
  step 'Setup: InfluxDB', 'bin/influxdb-restart.sh'

  step 'Lint: Ruby', 'bin/rubocop --parallel'
  step 'Lint: Slim templates', 'bundle exec slim-lint .'
  step 'Lint: JavaScript', 'bin/yarn lint'
  step 'Check: TypeScript', 'bin/yarn tsc'

  step 'Security: Gem audit', 'bin/bundler-audit'
  step 'Security: NPM audit', 'bin/yarn npm audit'
  step 'Security: Brakeman code analysis',
       'bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error'

  step 'Setup: Clean coverage', 'rm -rf coverage/.resultset.json'
  step 'Tests: Unit',
       'env COVERAGE_NAME=unit DISABLE_SPRING=1 bin/rspec --exclude-pattern "spec/system/**/*_spec.rb"'
  step 'Tests: System',
       'env COVERAGE_NAME=system PLAYWRIGHT_HEADLESS=true DISABLE_SPRING=1 bin/rspec spec/system'

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
