# Run using bin/ci

# parallel_step and spec_step, the parts that use more than one process.
require_relative 'ci/parallel'

# Every worker boots Rails before it runs a single example, and past ten the
# boots cost more than the extra parallelism returns: 21s at ten workers, 25s
# at eight, 24s at twelve, 28s at sixteen, 30s at twenty.
UNIT_WORKERS = ParallelCI.workers_upto(10)

# The longest of the twenty system spec files takes 48 seconds on its own, so
# no number of workers brings the suite under about 52. More browsers only add
# contention: 59s at six, 62s at eight, 66s at ten, 78s at twenty.
SYSTEM_WORKERS = ParallelCI.workers_upto(6)

# slim-lint shares the machine with `rubocop --parallel`, which already asks
# for every core, so this stays modest.
LINT_WORKERS = ParallelCI.workers_upto(8)

# Both spec runs number their workers from the same base, so the larger of the
# two counts is how many test databases bin/ci has to create.
MAX_WORKERS = [UNIT_WORKERS, SYSTEM_WORKERS].max

# How long each system spec file took last time, so that every worker gets the
# same amount of work. Six of the twenty files hold three quarters of the
# runtime, so a split by file size puts three of them on one worker while the
# others wait: 2 minutes instead of 1.
#
# The unit specs get no log on purpose. RuntimeLogger charges the warm-up of a
# worker to the first file that worker runs, and for a 7 second file that adds
# 25 seconds. Six files per run come out that wrong, the split follows them,
# and the next run picks six different ones. Measured over three runs each:
# 21 to 26 seconds by file size against 26 to 48 seconds by runtime.
SYSTEM_RUNTIME_LOG = 'tmp/parallel_runtime_system.log'.freeze

ParallelCI.run do
  parallel_step 'Setup' do
    check 'InfluxDB', 'bin/influxdb-restart.sh'
    check 'Remove previous coverage results', 'rm -rf coverage/.resultset.json'

    # One database per worker. Creating them is idempotent, and rails_helper
    # loads the schema into an empty one through maintain_test_schema!.
    check 'Test databases', "bin/rake 'parallel:create[#{MAX_WORKERS}]'", env: { RAILS_ENV: 'test', DISABLE_SPRING: 1 }
  end

  parallel_step 'Style and security' do
    check 'Ruby', 'bin/rubocop --parallel'
    check 'JavaScript', 'bun run lint'
    check 'TypeScript', 'bun run tsc'
    check 'Shell', "shellcheck $(git ls-files '*.sh')"
    check 'Markdown, JSON, YAML, CSS', 'bun run format:check'
    check 'Gem audit', 'bin/bundler-audit'
    check 'JavaScript vulnerability audit', 'bun audit'
    check 'Brakeman code analysis', 'bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error'

    # slim-lint runs on one core and keeps no cache, so it is the slowest
    # check by far. Splitting the files over processes brings it down from
    # 32 to 14 seconds.
    check 'Slim', "git ls-files '*.slim' | xargs -n 20 -P #{LINT_WORKERS} bin/slim-lint"
  end

  # The table of every built asset says nothing that a green build needs to
  # say. `warn` keeps the warnings and the errors. The request specs render
  # layouts that read the Vite manifest, so this runs before both spec steps.
  step 'Build: Vite assets', 'bunx vite build --mode test --logLevel warn'

  # parallel_tests sets DISABLE_SPRING itself, so the spec steps carry only
  # what differs between them.
  spec_step(
    'Tests: Unit',
    'spec',
    # A regex on the path. The trailing slash keeps it to the directory, so
    # that a spec/system_something_spec.rb file stays in the unit run.
    exclude: 'spec/system/',
    processes: UNIT_WORKERS,
    env: { COVERAGE_NAME: 'unit' },
  )

  spec_step(
    'Tests: System',
    'spec/system',
    processes: SYSTEM_WORKERS,
    runtime_log: SYSTEM_RUNTIME_LOG,
    env: { COVERAGE_NAME: 'system', PLAYWRIGHT_HEADLESS: true },
  )

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
