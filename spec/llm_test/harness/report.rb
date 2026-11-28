module LlmTest
  # Turns the records of a run into the two things worth looking at: what each
  # case does per model, and how that differs from a baseline.
  #
  # The diff is the point of the whole suite. A single run says "8 of 10
  # passed"; against a baseline it says "list_sensors calls 4.0 -> 1.2, input
  # tokens 31k -> 18k, and ranking_partial_periods broke".
  class Report
    # A command line tool, not a spec: printing is how it reports.
    # rubocop:disable RSpec/Output
    ROW = '%-30s %-9s %-16s %-8s %-10s %s'.freeze
    public_constant :ROW

    # `ablated` names the text that was withheld from the tool list, so a run
    # that measured a server WITHOUT one of its sentences cannot be read - or
    # saved - as a reference for the one that ships.
    def initialize(records, ablated: nil)
      @records = records
      @ablated = ablated
    end

    # case + model -> the aggregate a report line and a diff are built from.
    def summary
      @summary ||=
        @records
          .group_by { [_1[:case], _1[:model]] }
          .transform_values do |runs|
            {
              'runs' => runs.size,
              'passed' => runs.count { _1[:passed] },
              'tool_calls' => average(runs, :tool_calls),
              'context_tokens' => average(runs, :context_tokens),
              'cost_usd' => runs.sum { _1[:cost_usd].to_f },
              'seconds' => runs.sum { _1[:seconds].to_f },
              'failures' => runs.flat_map { _1[:failures] }.tally,
            }
          end
    end

    def show # rubocop:disable Metrics/AbcSize
      puts
      puts format(ROW, 'CASE', 'MODEL', 'PASS', 'CALLS', 'CONTEXT', 'COST')
      puts '-' * 84

      summary.each do |(id, model), data|
        puts format(
               ROW,
               id.to_s[0, 29],
               model,
               "#{data['passed']}/#{data['runs']}",
               data['tool_calls'].round(1).to_s,
               thousands(data['context_tokens']),
               format('$%.3f', data['cost_usd']),
             )
      end

      puts
      puts "#{passed} of #{@records.size} runs passed. " \
             "#{format('$%.2f', @records.sum { _1[:cost_usd].to_f })} spent, " \
             "#{thousands(@records.sum { _1[:context_tokens].to_i })} tokens read, " \
             "#{thousands(@records.sum { _1[:output_tokens].to_i })} written."
      puts "Models: #{describe(versions)}." if versions.any?
      print_usage
      print_failures
    end

    # The share of the subscription windows the run consumed. A Claude
    # subscription is not billed per token, so this - not the dollar figure -
    # is what a run costs the person who started it.
    def print_usage
      windows = @records.filter_map { _1[:rate_limit].presence }
      return if windows.empty?

      windows.first.each_key do |name|
        values = windows.filter_map { _1[name] }.compact
        next if values.empty?

        puts "#{name.tr('_', ' ')} usage window: " \
               "#{values.min.round(2)}% -> #{values.max.round(2)}% of the subscription."
      end
    end

    def print_failures
      failures = @records.flat_map { _1[:failures] }.tally.sort_by { |_text, count| -count }
      return if failures.empty?

      puts
      puts 'What went wrong:'
      failures.each { |text, count| puts "  #{count}x #{text}" }
    end

    # The cases whose pass rate fell below the baseline and that have fewer
    # than `runs` runs: { [case id, model] => runs done }. More runs of these
    # tell a change from chance (see Significance).
    def doubtful(baseline, runs)
      summary.filter_map do |key, now|
        old = baseline['summary'][key.join(' / ')]
        next unless old && now['runs'] < runs && Significance.lower?(old, now)

        [key, now['runs']]
      end.to_h
    end

    # Every case+model the two runs share, with the numbers that moved.
    def show_diff(baseline) # rubocop:disable Metrics/AbcSize
      before = baseline['summary']
      print_version_change(baseline['versions'])

      puts
      puts format(ROW, 'CASE', 'MODEL', 'PASS', 'CALLS', 'CONTEXT', '')
      puts '-' * 84

      flags =
        summary.filter_map do |key, now|
          old = before[key.join(' / ')]
          next puts(format(ROW, key.first[0, 29], key.last, 'new', '', '', '')) unless old

          flag = flag(old, now)
          puts format(
                 ROW,
                 key.first[0, 29],
                 key.last,
                 "#{rate(old)} -> #{rate(now)}#{flag}",
                 "#{old['tool_calls'].round(1)}->#{now['tool_calls'].round(1)}",
                 "#{thousands(old['context_tokens'])}->#{thousands(now['context_tokens'])}",
                 '',
               )
          flag.strip.presence
        end

      print_verdict(flags.tally)
      print_small_baseline(before)
    end

    # The saved run, without the subscription usage: that number belongs on the
    # console of the person who started the run, not in a file the repository
    # keeps. It says nothing about the server and everything about an account.
    def to_h
      {
        'recorded_at' => Time.current.iso8601,
        **(@ablated ? { 'ablated' => @ablated } : {}),
        'commit' => `git rev-parse --short HEAD`.strip,
        'versions' => versions,
        'summary' => summary.transform_keys { _1.join(' / ') },
        'records' => @records.map { _1.except(:rate_limit) },
      }
    end

    # What a later run compares against: the summary, without the single runs.
    # A baseline lives in the repository, and the answers of 450 runs would add
    # half a megabyte to it that no diff reads. They stay in results/.
    def to_baseline = to_h.except('records')

    # The versions that ran behind each model alias, and behind the judge,
    # like { "haiku" => ["claude-haiku-5-5"] }. An alias moves to the next
    # version of a model, so a saved run keeps them.
    def versions
      @versions ||=
        @records
          .group_by { _1[:model] }
          .transform_values { versions_of(_1, :model_id) }
          .merge('judge' => versions_of(@records, :judge_model))
          .reject { |_name, ids| ids.empty? }
    end

    private

    # A diff across two versions of a model measures the model, not the
    # server, so the diff says so first
    def print_version_change(before)
      if before.nil?
        puts "\nThe baseline names no model versions."
      elsif before != versions
        puts "\nThe models differ: #{describe(before)} in the baseline, #{describe(versions)} now."
      end
    end

    def versions_of(runs, key) = runs.filter_map { _1[key] }.uniq.sort

    def describe(versions) = versions.map { |name, ids| "#{name} = #{ids.join(', ')}" }.join('; ')

    def passed = @records.count { _1[:passed] }

    def average(runs, key)
      runs.sum { _1[key].to_i } / runs.size.to_f
    end

    def rate(data) = "#{data['passed']}/#{data['runs']}"

    # A regression is worth a mark; an improvement speaks for itself. `!` is
    # a drop that chance does not explain, `?` one that it does.
    def flag(old, now)
      return '' unless Significance.lower?(old, now)

      Significance.worse?(old, now) ? ' !' : ' ?'
    end

    def print_verdict(flags)
      return if flags.empty?

      puts
      puts "! worse beyond chance (p < #{Significance::ALPHA}): #{count(flags['!'])}" if flags['!']
      puts "? lower, but chance can explain it: #{count(flags['?'])}" if flags['?']
    end

    # A small baseline hides all but a large drop. Saying so keeps a `?` from
    # reading as "all is well".
    def print_small_baseline(before)
      runs = summary.keys.filter_map { before.dig(_1.join(' / '), 'runs') }.min
      return if runs.nil? || runs >= Significance::RUNS

      puts
      puts "The baseline has #{runs} runs per case, too few to show a moderate drop. " \
             "Record it with --runs #{Significance::RUNS}."
    end

    def count(number) = number == 1 ? '1 case' : "#{number} cases"

    def thousands(number) = "#{(number / 1000.0).round(1)}k"
    # rubocop:enable RSpec/Output
  end
end
