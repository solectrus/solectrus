# A progress formatter without the progress.
#
# bin/ci runs the specs on several processes with --serialize-stdout, which
# holds back what a worker writes until that worker is done. A dot that
# appears after the example already passed shows nothing, and 3313 of them
# bury the part that matters. A green worker is down to its two summary
# lines here, while a failing one still prints everything it used to.
#
# parallel_tests reads the count of examples and failures back out of the
# summary line, so that line has to stay.
#
# RSpec resolves `--format QuietFormatter` by requiring "quiet_formatter",
# which is why this sits in spec/ and not in spec/support/.
#
# The register call is what puts the class into RSpec's formatter list. An
# inherited registration does not count: Loader#add looks the exact class up,
# and without a hit it drops the formatter and warns about a legacy interface.
class QuietFormatter < RSpec::Core::Formatters::ProgressFormatter
  RSpec::Core::Formatters.register self,
                                   :example_passed,
                                   :example_pending,
                                   :start_dump,
                                   :dump_summary,
                                   :seed

  def example_passed(_notification); end

  def example_pending(_notification); end

  # Only there to end the line of dots, and there are none.
  def start_dump(_notification); end

  # parallel_tests already puts a blank line in front of what each worker
  # wrote, and the summary brings a leading and a trailing one of its own.
  # Three blank lines between ten workers is most of the report.
  def dump_summary(notification)
    @failed = notification.failure_count.positive?

    output.puts notification.fully_formatted.strip
  end

  # The seed is what reproduces a random order, so it is worth having after a
  # failure. RSpec prints it before the run as well, where nothing has failed
  # yet, and twice per worker adds up to nothing but noise.
  def seed(notification)
    super if @failed
  end
end
