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

    def initialize(records)
      @records = records
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

    # Every case+model the two runs share, with the numbers that moved.
    def show_diff(baseline)
      before = baseline['summary']

      puts
      puts format(ROW, 'CASE', 'MODEL', 'PASS', 'CALLS', 'CONTEXT', '')
      puts '-' * 84

      summary.each do |key, now|
        old = before[key.join(' / ')]
        next puts(format(ROW, key.first[0, 29], key.last, 'new', '', '', '')) unless old

        puts format(
               ROW,
               key.first[0, 29],
               key.last,
               "#{rate(old)} -> #{rate(now)}#{flag(old, now)}",
               "#{old['tool_calls'].round(1)}->#{now['tool_calls'].round(1)}",
               "#{thousands(old['context_tokens'])}->#{thousands(now['context_tokens'])}",
               '',
             )
      end
    end

    # The saved run, without the subscription usage: that number belongs on the
    # console of the person who started the run, not in a file the repository
    # keeps. It says nothing about the server and everything about an account.
    def to_h
      {
        'recorded_at' => Time.current.iso8601,
        'commit' => `git rev-parse --short HEAD`.strip,
        'summary' => summary.transform_keys { _1.join(' / ') },
        'records' => @records.map { _1.except(:rate_limit) },
      }
    end

    private

    def passed = @records.count { _1[:passed] }

    def average(runs, key)
      runs.sum { _1[key].to_i } / runs.size.to_f
    end

    def rate(data) = "#{data['passed']}/#{data['runs']}"

    # A regression is worth a mark; an improvement speaks for itself.
    def flag(old, now)
      return ' !' if now['passed'].to_f / now['runs'] < old['passed'].to_f / old['runs']

      ''
    end

    def thousands(number) = "#{(number / 1000.0).round(1)}k"
    # rubocop:enable RSpec/Output
  end
end
