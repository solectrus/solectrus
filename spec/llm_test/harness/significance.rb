module LlmTest
  # Is a lower pass rate a change, or the chance of a few runs?
  #
  # A model is not deterministic: the same code passes a case 2 of 3 times
  # today and 3 of 3 times tomorrow. A drop counts as a change only when chance
  # explains it in fewer than one of twenty cases.
  #
  # Fisher's exact test, one-sided: the probability that the current run shows
  # at least as many failures as it does, if the baseline and the current run
  # had the same pass rate. Exact, in integers, because the counts are small -
  # an approximation is worst exactly where this suite lives.
  module Significance
    ALPHA = 0.05
    public_constant :ALPHA

    # Runs per case on both sides before a moderate drop can be told from
    # chance: 10 of 10 against 6 of 10 is beyond it, against 7 of 10 not yet.
    # With three runs, only a drop to about 2 of 10 is.
    RUNS = 10
    public_constant :RUNS

    module_function

    # `old` and `now` are summaries of one case, with 'passed' and 'runs'.
    def worse?(old, now) = lower?(old, now) && p_worse(old, now) < ALPHA

    def lower?(old, now) = now['passed'] * old['runs'] < old['passed'] * now['runs']

    def p_worse(old, now)
      runs = old['runs'] + now['runs']
      failed = runs - old['passed'] - now['passed']
      now_failed = now['runs'] - now['passed']

      ways =
        (now_failed..[failed, now['runs']].min).sum do |count|
          choose(failed, count) * choose(runs - failed, now['runs'] - count)
        end

      ways.fdiv(choose(runs, now['runs']))
    end

    def choose(total, pick)
      return 0 if pick.negative? || pick > total

      # Each step is C(total, elem + 1), so the division is always exact
      (0...pick).reduce(1) { |acc, elem| acc * (total - elem) / (elem + 1) }
    end
  end
end
