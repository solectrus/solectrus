module LlmTest
  # Runs every case against every model, N times, and hands the records to the
  # report.
  #
  # N times, because a model is not deterministic: a single run tells you
  # nothing, a pass rate over five tells you whether a description works.
  #
  # The runs go through a pool of threads. Each one is a `claude` process of its
  # own and spends its time waiting for the API, so the wall clock drops by the
  # number of jobs while the measurement stays what it was.
  class Runner
    # A command line tool, not a spec: printing is how it reports.
    # rubocop:disable RSpec/Output
    def initialize(cases:, models:, runs:, socket:, jobs:, judge: nil, verbose: false) # rubocop:disable Metrics/ParameterLists
      @cases = cases
      @models = models
      @runs = runs
      @socket = socket
      @jobs = jobs
      @judge = judge
      @verbose = verbose
      @output = Mutex.new
      @done = 0
    end

    def call
      queue = Queue.new
      @models.each { |model| @cases.each { |c| @runs.times { |run| queue << [c, model, run] } } }
      @total = queue.size
      records = Concurrent::Array.new

      workers = Array.new([@jobs, @total].min) { worker(queue, records) }
      workers.each(&:join)

      records.to_a
    end

    private

    def worker(queue, records)
      Thread.new do # rubocop:disable ThreadSafety/NewThread
        while (job = queue.pop(true))
          records << perform(*job)
        end
      rescue ThreadError
        nil # queue is empty, this worker is done
      end
    end

    def perform(test_case, model, run)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result =
        ClaudeCli
          .new(model:, socket: @socket)
          .call(test_case.prompt, system: SystemPrompt.call)

      failures = test_case.check(result)
      verdict = judge(test_case, result) if failures.empty?
      failures << "judge: #{verdict.reason}" if verdict && !verdict.pass

      record(test_case, model, run, result, failures, started, verdict).tap { report(_1, result) }
    rescue ClaudeCli::Error => e
      failed(test_case, model, run, "claude failed: #{e.message}")
    end

    # The judge is asked only when the mechanical checks passed. It costs a
    # request, and an answer that already failed one of them needs no second
    # opinion.
    def judge(test_case, result)
      return unless @judge && test_case.judge

      Judge.new(model: @judge).call(test_case, result)
    end

    def record(test_case, model, run, result, failures, started, verdict) # rubocop:disable Metrics/ParameterLists
      {
        case: test_case.id,
        prompt: test_case.prompt,
        model:,
        run:,
        passed: failures.empty?,
        failures:,
        tools: result.tool_names,
        calls: result.tool_calls.map { { name: _1.name, arguments: _1.arguments, error: _1.error } },
        tool_calls: result.tool_calls.size,
        input_tokens: result.input_tokens,
        output_tokens: result.output_tokens,
        context_tokens: result.context_tokens,
        # The judge costs a request of its own; a run's price is both of them.
        cost_usd: result.cost_usd + verdict&.cost_usd.to_f,
        rate_limit: result.rate_limit,
        seconds: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1),
        answer: result.answer,
      }
    end

    def failed(test_case, model, run, message)
      {
        case: test_case.id,
        model:,
        run:,
        passed: false,
        failures: [message],
        tools: [],
        calls: [],
        tool_calls: 0,
        cost_usd: 0.0,
      }.tap { report(_1, nil) }
    end

    # One block per run, written in one piece so parallel workers cannot
    # interleave their lines.
    def report(record, result)
      @output.synchronize do
        @done += 1
        puts header(record)
        record[:failures].each { puts "      #{_1}" }
        puts details(record, result) if @verbose
      end
    end

    def header(record)
      mark = record[:passed] ? "\e[32m✔\e[0m" : "\e[31m✘\e[0m"

      "[#{@done}/#{@total}] #{mark} #{record[:model]} #{record[:case]} " \
        "(#{record[:tool_calls]} calls, #{record[:context_tokens]} ctx, " \
        "#{format('$%.3f', record[:cost_usd].to_f)}, #{record[:seconds]}s)"
    end

    def details(record, result)
      return '' unless result

      lines = ["      ? #{record[:prompt]}"] +
        record[:calls].map do |call|
          rejected = call[:error] ? ' [rejected]' : nil
          "      → #{call[:name]}(#{call[:arguments].to_json})#{rejected}"
        end

      (lines + record[:answer].to_s.lines.map { "      #{_1.chomp}" }).join("\n")
    end
  end

  # What a client puts around the server's own instructions: who it is talking
  # to, and what day it is. Nothing about the tools themselves - that text is
  # what is under test, and it reaches the model from the MCP handshake.
  module SystemPrompt
    module_function

    def call
      <<~TEXT.strip
        You are an assistant with access to the user's SOLECTRUS photovoltaic
        monitoring system through its MCP tools. Answer the user's question in
        the language they used, and name the numbers you found. Be brief.

        Today is #{Dataset.today.strftime('%A, %-d %B %Y')}, the time is #{Dataset.now.strftime('%H:%M')}.
      TEXT
    end
    # rubocop:enable RSpec/Output
  end
end
