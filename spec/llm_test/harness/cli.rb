# These files live under spec/ so they stay out of the Docker image, but they
# are a command line tool and not a spec: printing is how they report.
# rubocop:disable RSpec/Output
require 'optparse'
require 'open3'
require 'socket'

module LlmTest
  # `bin/llm-test` itself: options, the frozen clock, the fixture, the MCP bridge,
  # the run, the report.
  class Cli
    ROOT = File.expand_path('..', __dir__)
    public_constant :ROOT

    # Model aliases of the `claude` CLI, so a run always takes the current
    # model of that tier.
    #
    # Haiku alone by default: it is the cheapest and the strictest reader of a
    # description - what confuses it usually confuses the others too, and it
    # shows a weak description first. Add sonnet with --models when a change
    # looks good on haiku and you want the second opinion.
    DEFAULT_MODELS = %w[haiku].freeze
    public_constant :DEFAULT_MODELS

    SOCKET = '/tmp/solectrus-llm-test-mcp.sock'.freeze
    public_constant :SOCKET

    # The fixture is written for good, not rolled back like a spec's data, so
    # it gets a database of its own. Sharing solectrus_test would leave 75 days
    # of summaries behind for the next `bin/rspec`.
    DATABASE = 'solectrus_llm_test'.freeze
    public_constant :DATABASE

    include ActiveSupport::Testing::TimeHelpers

    def self.call(argv) = new(argv).call

    def initialize(argv)
      @options = {
        models: DEFAULT_MODELS,
        runs: 3,
        jobs: 4,
        judge: Judge::DEFAULT_MODEL,
        verbose: false,
        only: nil,
        baseline: nil,
        save: nil,
      }
      parser.parse!(argv)
    end

    def call
      abort 'The `claude` CLI is not installed.' unless system('command -v claude > /dev/null')

      cases = load_cases
      abort 'No cases selected.' if cases.empty?

      finish(Report.new(run(cases)))
    end

    private

    def run(cases)
      records = nil

      connect_to_own_database!

      travel_to(Dataset.now) do
        seed
        bridge = Bridge.new(SOCKET).start

        begin
          announce(cases)
          records =
            Runner.new(
              cases:,
              socket: SOCKET,
              **@options.slice(:models, :runs, :jobs, :judge, :verbose),
            ).call
        ensure
          bridge.stop
        end
      end

      records
    end

    # A run is quiet until its first `claude` process answers, which takes ten
    # seconds or more. Saying what is being built, and what is about to run,
    # keeps that silence from reading as a hang.
    def seed
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      Dataset.seed!
      seconds = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1)

      puts "Fixture in #{DATABASE}: #{Dataset.first_day} to #{Dataset.yesterday} " \
             "summarized, #{Dataset.today} measured up to #{Dataset.now.strftime('%H:%M')} (#{seconds}s)"
    end

    def announce(cases)
      runs = cases.size * @options[:models].size * @options[:runs]

      puts "Running #{runs} tests: #{cases.size} cases x " \
             "#{@options[:models].join(', ')} x #{@options[:runs]} runs, " \
             "#{@options[:jobs]} at a time. A single run takes 10-30 seconds."
    end

    # Creates the test database on first use and loads the current schema into
    # it, the way `db:prepare` would.
    def connect_to_own_database!
      config = ActiveRecord::Base.connection_db_config.configuration_hash.merge(database: DATABASE)
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection.tables
    rescue ActiveRecord::NoDatabaseError
      puts "Creating #{DATABASE} ..."
      ActiveRecord::Tasks::DatabaseTasks.create(config) # rubocop:disable Rails/SaveBang
      ActiveRecord::Base.establish_connection(config)
      load Rails.root.join('db', 'schema.rb')
    end

    def finish(report)
      report.show
      report.show_diff(JSON.parse(File.read(@options[:baseline]))) if @options[:baseline]

      path = @options[:save] || File.join(ROOT, 'results', "#{Time.current.to_i}.json")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "#{JSON.pretty_generate(report.to_h)}\n")
      puts "\nWritten to #{path}"
    end

    def load_cases
      cases = Case.load_all(File.join(ROOT, 'cases'))
      return cases unless @options[:only]

      cases.select { _1.id.match?(/#{@options[:only]}/) }
    end

    def parser
      OptionParser.new do |opts|
        opts.banner = 'Usage: bin/llm-test [options]'

        opts.on('--models a,b', Array, "Models to run (default: #{DEFAULT_MODELS.join(',')})") do |models|
          @options[:models] = models
        end
        opts.on('--runs N', Integer, 'Runs per case and model (default: 3)') { @options[:runs] = _1 }
        opts.on('--jobs N', Integer, 'Runs in parallel (default: 4)') { @options[:jobs] = _1 }
        opts.on('--only PATTERN', 'Only cases whose id matches') { @options[:only] = _1 }
        opts.on('--baseline PATH', 'Compare against this result file') { @options[:baseline] = _1 }
        opts.on('--save PATH', 'Write the result file here') { @options[:save] = _1 }
        opts.on('--no-judge', 'Skip the LLM judge, run the mechanical checks alone') do
          @options[:judge] = false
        end
        opts.on('--judge-model MODEL', "Model that grades the answers (default: #{Judge::DEFAULT_MODEL})") do |model|
          @options[:judge] = model
        end
        opts.on('--verbose', 'Print every tool call and every answer') { @options[:verbose] = true }
      end
    end
  end
end
# rubocop:enable RSpec/Output
