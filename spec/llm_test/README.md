# LLM tests for the MCP server

The specs in `spec/lib/mcp_server/` make sure that the server returns correct
JSON. These tests answer a different question: does a model find the short and
correct way with the tool descriptions that we ship?

One test sends a real question to a real model, gives it our MCP tools, and
records three things:

- The trajectory: which tools the model called, in which order, with which
  arguments.
- The cost: how large the context was, and how many tool calls the answer took.
- The answer: does it carry the correct number, and does it read the
  conventions correctly?

The tests run local and manual. `bin/ci` never starts them.

## Requirements

- The `claude` CLI, with a Claude subscription. The tests go through
  `claude --print`, so they are not billed per token.
- A running InfluxDB. Start it with `bin/influxdb-restart.sh`.
- PostgreSQL. The tests create the database `solectrus_llm_test` on the first run
  and load the current schema into it. The suite of specs is not touched.

The files live under `spec/` because the Docker image excludes that directory.
They are not RSpec files, and `bin/rspec` does not collect them.

## How to run

```sh
bin/llm-test                             # all cases, haiku, 3 runs each, 4 in parallel
bin/llm-test --only totals --verbose     # one case, with every tool call and answer
bin/llm-test --models haiku,sonnet       # a second model
bin/llm-test --runs 5 --jobs 8           # more runs, more of them at a time
bin/llm-test --no-judge                  # mechanical checks alone, no LLM judge
bin/llm-test --judge-model sonnet        # a stronger grader when a verdict looks wrong
bin/llm-test --save spec/llm_test/baselines/before.json
bin/llm-test --baseline spec/llm_test/baselines/before.json
```

Haiku alone is the default. It is the cheapest model and the strictest reader
of a description: what confuses Haiku usually confuses the others too. Add
sonnet when a change looks good and you want the second opinion.

Each line reports the number of tool calls, the largest context the model read,
the cost of that run and its duration. The cost is what the `claude` CLI itself
reports for that run, and it covers the judge as well - the judge grades on
Haiku too, so it never costs more than the run it grades. Every run writes a result file to
`spec/llm_test/results/`, with the tool calls, the arguments and the answer of
each single run.

## A red case is a finding

Every case has to pass in every run. A case states a rule the server enforces,
and a rule that holds four times out of five is not enforced - so the suite
measures what a description can decide (which tool, which arguments, which
unit) and leaves out what it can only make more likely. A case that turns red
now and then is not a flaky test; it is a description that does not carry.

The checks are strict on purpose. When a case fails, read the tool calls before
you change the case: "called `list_sensors` although the sensor was named in
the question" and "invented the sensor name `pv_production`" are results about
our descriptions, not broken tests. Change a case only when it measures the
fixture instead of the server.

## Why several runs

A model is not deterministic. One run tells you nothing. Three to five runs per
case and model give a pass rate, and the pass rate is what you compare. The
runs go through a pool of threads (`--jobs`, 4 by default), so more runs cost
time in proportion to the pool, not to their number.

## The baseline is the point

A single report says "8 of 10 runs passed". A comparison says what a change to
a description did:

```sh
bin/llm-test --runs 5 --save spec/llm_test/baselines/before.json
# change a tool description
bin/llm-test --runs 5 --baseline spec/llm_test/baselines/before.json
```

The diff shows the pass rate, the average number of tool calls and the context
size, for each case and model, before and after. A `!` marks a case that got
worse.

## How a case works

A case is one entry in `spec/llm_test/cases/*.yml`:

```yaml
- id: totals_yesterday_direct
  prompt: Wie viel Strom hat meine PV-Anlage gestern erzeugt?
  expect_tools: [get_totals]
  forbid_tools: [list_sensors]
  max_tool_calls: 2
  expect_args:
    get_totals:
      sensors: [inverter_power]
  expect_facts: [pv_yesterday_kwh]
  judge: Names the generated energy in kWh or Wh.
```

The keys:

| Key                     | Meaning                                                             |
| ----------------------- | ------------------------------------------------------------------- |
| `prompt`                | The question, in the language a user asks it in.                    |
| `expect_tools`          | Each of these tools must be called at least once.                   |
| `forbid_tools`          | None of these may be called.                                        |
| `max_tool_calls`        | Upper limit for the number of calls.                                |
| `expect_args`           | Arguments the first call of a tool must carry.                      |
| `expect_facts`          | Numbers from `Dataset.facts` that the answer must name.             |
| `answer_must_match`     | Regular expressions the answer must match.                          |
| `answer_must_not_match` | Regular expressions the answer must not match.                      |
| `allow_tool_errors`     | Permits a rejected tool call, which is a failure by default.        |
| `judge`                 | One criterion for the LLM judge. It runs only if all checks passed. |
| `note`                  | Why this case exists. It is documentation, not a check.             |

A case never repeats a number. It names a fact, and `Dataset.facts` computes
the value from the same curves that the fixture was built from.

## The fixture

`spec/llm_test/harness/dataset.rb` builds a deterministic installation:

- The clock stands at the real time, frozen when the run starts. Therefore
  yesterday is a full day and the running month is not over. It has to be the
  real time for two reasons: Claude Code tells the model what day it is, and
  InfluxDB answers "what is the current value" from its own wall clock. A
  fixture in the past made the model ask for a timeframe wide of the data, and
  a fixture in the future put the live readings where no query finds them.
- Summaries in PostgreSQL, from the start of the month before last.
- Measurements in InfluxDB, one per minute, for yesterday and today.
- One consumer carries an operator name ("Waschmaschine" for
  `custom_power_01`), because only `list_sensors` can resolve such a name.

One generator feeds both stores, so InfluxDB and the summaries always agree.

## How the model reaches the server

Claude Code speaks stdio to an MCP server, and stdio means one process per run.
A Rails boot per run is too slow, so the Rails side stays in the harness
process: it opens a UNIX socket, and `spec/llm_test/shim.rb` pipes the traffic of one
run to that socket. What crosses the socket is what `McpController` hands to
the transport. The model therefore reads the tool list and the descriptions
that we ship, byte for byte, without an HTTP server or an OAuth token.

Every run starts with `--tools ""`, so Claude Code brings no tool of its own.
The model has our 12 MCP tools and nothing else.

One Ruby process answers all the parallel runs, so a tool call waits for the
others. The runs therefore raise the MCP timeouts of the CLI (`MCP_TIMEOUT`,
`MCP_TOOL_TIMEOUT`), which assume a server per client. Without that, a busy
bridge shows up as a rejected `list_sensors` - or as a run that starts with no
tools at all, because the handshake timed out. A rejected call now carries the
reason, which tells the two apart.
