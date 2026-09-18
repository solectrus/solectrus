# Testing

Every test runner of this repository, and what each one is for. `docs/conventions.md` says how to write a spec, this file says how to run one.

## The specs

`bin/rspec [path]` runs the specs. InfluxDB must run before they start. Start it with `bin/influxdb-restart.sh` and never by hand. The script recreates the `influxdb_v2` container with the org, the bucket and the token that the test environment expects. The local InfluxDB exists for the tests alone, so its data costs nothing to drop. Run the script whenever a spec cannot reach InfluxDB.

## System specs

System specs drive Playwright and they are slow. Run them only when the change affects UI behavior or JavaScript, and when a request spec cannot cover it.

Always run them with `PLAYWRIGHT_HEADLESS=true`. Without it, browser windows open in the foreground and block the machine.

They run against compiled assets. After a change to the frontend, run `bunx vite build --mode test` first.

For a display problem on iOS, the `ios-simulator` skill runs SOLECTRUS on an iPhone in the simulator. It opens the application as a page in Safari or as the installed PWA.

## The full gate

`bin/ci` runs every linter, the security audits, the asset build and both spec runs. It does locally what GitHub CI does, and it adds the gem and package audits, which GitHub CI runs nightly. Use it before a release rather than after each change.

### Layout

`config/ci.rb` holds the steps and nothing else. `config/ci/parallel.rb` holds the class that runs a step on several processes. `bin/ci` loads both.

A step is one of three kinds:

- `step` runs one command. Rails ships this one.
- `parallel_step` takes a block of `check` lines, runs them at the same time, and reports them as one step.
- `spec_step` runs the specs of the given paths through `parallel_tests`.

Both `check` and `spec_step` take an `env:` hash. The command line gets it as an `env` prefix.

### How many processes

By default a step uses one process per CPU core. The unit specs stop at ten and the system specs at six. The comments in `config/ci.rb` give the measurements behind those two numbers.

`PARALLEL_TEST_PROCESSORS` sets the number for every step at once. It can go above the two limits. This is the variable that `parallel_tests` itself documents.

### Output

A green check prints its name and nothing else. Nine commands that write at the same time are unreadable, and on a green run none of it is worth reading. A check that fails prints everything it wrote.

The specs use `spec/quiet_formatter.rb`. It drops the progress dots and keeps the failures and the summary. The dots say nothing here, because `--serialize-stdout` holds back what a worker writes until that worker is done.

### How the work is split

`parallel_tests` splits the spec files over the processes. For the system specs, `bin/ci` writes how long each file took to `tmp/parallel_runtime_system.log` and reads it back on the next run. Every process then gets the same amount of work. After `rails tmp:clear` the first run is slower, because it must split the files by size instead.

The unit specs always split by size. The comment in `config/ci.rb` says why.

### Isolation

Every spec process gets its own Postgres database and its own InfluxDB bucket. Both carry the number that `parallel_tests` puts into `TEST_ENV_NUMBER`. The `Setup` step creates the databases, and `spec/support/influx_bucket.rb` creates the buckets. A plain `bin/rspec` run gets no such number and keeps the `solectrus_test` database and the `my-bucket` bucket.

`docs/conventions.md` says what this means for a spec you write.

## The Docker image

`bin/image-test.sh` runs the Docker image that the Dockerfile builds and checks that it works. Nothing else starts it, because GitHub CI builds it and pushes it without running it.

The script needs Docker. It builds the Docker image itself when you name none, and it takes one as its first argument. CI runs it on every build of the image. Run it locally when you change the `Dockerfile`, `docker/entrypoint.sh` or `config/docker_image.rb`.

## The MCP tools

`bin/llm-test` runs the LLM tests of the MCP server against the `claude` CLI. They cost subscription usage and they take minutes. Run them when a tool description or the server instructions change, and never as part of a normal test run.

Before you add prose to a description, `--ablate` measures what the sentence already there is worth. `spec/llm_test/README.md` describes the tests and the cases they run.
