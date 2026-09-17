# Continuous Integration

`bin/ci` runs the full gate: every linter, the security audits, the asset build and both spec runs. It does locally what GitHub CI does, and it adds the gem and package audits, which GitHub CI runs nightly. Use it before a release rather than after each change.

## Layout

`config/ci.rb` holds the steps and nothing else. `config/ci/parallel.rb` holds the class that runs a step on several processes. `bin/ci` loads both.

A step is one of three kinds:

- `step` runs one command. Rails ships this one.
- `parallel_step` takes a block of `check` lines, runs them at the same time, and reports them as one step.
- `spec_step` runs the specs of the given paths through `parallel_tests`.

Both `check` and `spec_step` take an `env:` hash. The command line gets it as an `env` prefix.

## How many processes

By default a step uses one process per CPU core. The unit specs stop at ten and the system specs at six. The comments in `config/ci.rb` give the measurements behind those two numbers.

`PARALLEL_TEST_PROCESSORS` sets the number for every step at once. It can go above the two limits. This is the variable that `parallel_tests` itself documents.

## Output

A green check prints its name and nothing else. Nine commands that write at the same time are unreadable, and on a green run none of it is worth reading. A check that fails prints everything it wrote.

The specs use `spec/quiet_formatter.rb`. It drops the progress dots and keeps the failures and the summary. The dots say nothing here, because `--serialize-stdout` holds back what a worker writes until that worker is done.

## How the work is split

`parallel_tests` splits the spec files over the processes. For the system specs, `bin/ci` writes how long each file took to `tmp/parallel_runtime_system.log` and reads it back on the next run. Every process then gets the same amount of work. After `rails tmp:clear` the first run is slower, because it must split the files by size instead.

The unit specs always split by size. The comment in `config/ci.rb` says why.

## Isolation

Every spec process gets its own Postgres database and its own InfluxDB bucket. Both carry the number that `parallel_tests` puts into `TEST_ENV_NUMBER`. The `Setup` step creates the databases, and `spec/support/influx_bucket.rb` creates the buckets. A plain `bin/rspec` run gets no such number and keeps the `solectrus_test` database and the `my-bucket` bucket.

`docs/conventions.md` says what this means for a spec you write.
