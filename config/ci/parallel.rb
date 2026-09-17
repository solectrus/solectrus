# The parts of bin/ci that use more than one process. config/ci.rb has the
# steps themselves.
#
# ActiveSupport::ContinuousIntegration runs one step after another and gives
# every step the whole machine. The subclass below lets a step use several
# processes, and lets several checks share the machine instead of queueing.
require 'open3'
require 'parallel'
require 'active_support/continuous_integration'

class ParallelCI < ActiveSupport::ContinuousIntegration
  # Collects the commands of a parallel_step, one `check` per line.
  class Checks
    attr_reader :commands

    def initialize
      @commands = {}
    end

    def check(name, command, env: {})
      @commands[name] = ParallelCI.with_env(command, env)
    end
  end

  # Prefixes a command with environment variables, the way a shell does.
  def self.with_env(command, env)
    return command if env.empty?

    "env #{env.map { |name, value| "#{name}=#{value}" }.join(' ')} #{command}"
  end

  # How many processes a step may use. PARALLEL_TEST_PROCESSORS is the variable
  # parallel_tests itself documents, and it overrides the cap for every step at
  # once. The caps come from measurements on a 20-core Mac, and a smaller
  # machine gets one process per core instead. Parallel.processor_count knows
  # about a container CPU quota, which Etc.nprocessors does not.
  def self.workers_upto(cap)
    Integer(ENV.fetch('PARALLEL_TEST_PROCESSORS') { [Parallel.processor_count, cap].min })
  end

  # Runs every `check` of the block at the same time and reports them as one
  # step.
  #
  # A green check prints its name and its runtime, and nothing else. Nine
  # commands writing at once is unreadable, and on a green run none of it is
  # worth reading: the 800 progress dots of RuboCop, the full Brakeman report,
  # the asset table. A failing check prints everything it wrote, which is the
  # part you need, below the list of all the checks.
  def parallel_step(title, &)
    commands = Checks.new.tap { it.instance_eval(&) }.commands

    heading title, "#{commands.size} checks, at the same time", type: :title

    report(title) { report_checks(commands) }
  end

  # A step that runs the specs of the given paths on several processes.
  # COVERAGE_NAME names the SimpleCov run, so that the two spec steps land in
  # the report side by side instead of overwriting each other.
  #
  # Without a runtime log parallel_tests splits the files by size.
  #
  # --serialize-stdout holds back what a worker writes until that worker is
  # done. Two workers that fail at the same time otherwise push their
  # `Failures:` blocks into each other, and their summary lines end up behind
  # both, which is the moment the output has to be readable.
  #
  # It also starts a heartbeat that prints a dot every 60 seconds, so that a
  # CI system does not take a quiet run for a hung one. In a terminal the dot
  # only lands in the middle of the report, and every other step of bin/ci is
  # already quiet while it works. PARALLEL_TEST_HEARTBEAT_INTERVAL below pushes
  # the heartbeat out of reach. Remove it to get the dots back.
  def spec_step(title, *paths, processes:, env: {}, exclude: nil, runtime_log: nil)
    # spec/quiet_formatter.rb says why the specs do not print progress here.
    # RuntimeLogger prints nothing at all, it only writes the log.
    formats = ['--format QuietFormatter']
    options = []
    options << "--exclude-pattern #{exclude}" if exclude

    if runtime_log
      options << "--runtime-log #{runtime_log}"
      formats << "--format ParallelTests::RSpec::RuntimeLogger --out #{runtime_log}"
    end

    command = [
      "bundle exec parallel_rspec -n #{processes}",
      '--serialize-stdout --combine-stderr',
      *options,
      "-o '#{formats.join(' ')}'",
      *paths,
    ].join(' ')

    heartbeat = { PARALLEL_TEST_HEARTBEAT_INTERVAL: 86_400 }

    step title, self.class.with_env(command, heartbeat.merge(env))
  end

  private

  # Starts every command in a thread of its own and returns the queue they
  # report to. A thread per command is what keeps this a single step, and every
  # thread only waits for a process of its own.
  def start_checks(commands)
    Queue.new.tap do |done|
      commands.each do |name, command|
        # rubocop:disable-next ThreadSafety/NewThread
        Thread.new do
          started_at = Time.now.to_f
          output, status = Open3.capture2e(command)
          done << [name, status.success?, Time.now.to_f - started_at, output]
        rescue StandardError => e
          done << [name, false, Time.now.to_f - started_at, "#{e.class}: #{e.message}"]
        end
      end
    end
  end

  # Prints a line per check, in the order the checks finish, so that the list
  # fills up while the slow checks still run. Waiting for the threads in the
  # order they were declared instead holds back every line behind the slowest
  # check before it, and the whole block lands at once after 30 quiet seconds.
  def report_checks(commands)
    done = start_checks(commands)
    failures = {}

    commands.size.times do
      name, success, elapsed, output = done.pop
      echo "  #{success ? '✅' : '❌'} #{name} (#{elapsed.round(1)}s)", type: success ? :success : :error

      failures[name] = output unless success
      results << success
    end

    # The output of a failing check comes after the list. Printed in place, it
    # pushes the checks that still run off the screen.
    failures.each do |name, output|
      echo "\n❌ #{name}", type: :error
      $stdout.puts output
    end
  end
end
