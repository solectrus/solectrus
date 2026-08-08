module McpServer
  # Every query over a day or longer reads the PostgreSQL summaries, and those
  # are built on demand: a web request that needs them builds them first (see
  # Sensor::Summarizer and the stats controllers), and nothing else does.
  #
  # An MCP client renders no page, so on this path nobody ever built them and a
  # query answered from whatever happened to exist. The running day has no
  # summary at all until something asks for one, which made "how much did I
  # produce today?" answer null while the inverter was feeding in, and left
  # every month total short by its current day - silently, since a missing day
  # is indistinguishable from a day that produced nothing.
  #
  # Building writes rows, so the tools that do it are not read-only in the
  # strictest sense. What they write is a cache of InfluxDB, though: it changes
  # no measurement and no setting, and the same GET requests build it in the
  # browser all day.
  module Summaries
    # Days one call builds before answering. A day costs about a quarter of a
    # second against InfluxDB (7 days per batch in ~1.7s, even with InfluxDB
    # throttled to half a core - see Sensor::Summarizer::CHUNK_SIZE), so a
    # whole month stays inside the seconds an MCP client waits.
    #
    # Beyond that the answer is given as it stands and says what it is missing.
    # An instance whose history was never opened in a browser has thousands of
    # days to build, which is the summaries page's job: it shows progress and
    # can take the minutes it needs.
    MAX_DAYS = 31
    public_constant :MAX_DAYS

    module_function

    # Builds the summaries `timeframe` needs and returns {}, or - where there
    # are more of them than one call may build - returns the note saying so, as
    # a hash to splat into the response. Empty in the common case, so a
    # timeframe that is already summarized pays nothing.
    #
    # "Now" and the hour timeframes are answered from raw measurements and need
    # no summary at all; Summary.missing_or_stale_days_for reports nothing
    # pending for them.
    def refresh(timeframe)
      pending = Summary.missing_or_stale_days_for(timeframe)
      return {} if pending.empty?
      return note(pending) if pending.size > MAX_DAYS

      Sensor::Summarizer.new(pending).call
      {}
    end

    def note(pending)
      {
        summary_note:
          "#{pending.size} days here have no summary yet and are missing " \
            'from this answer, so a sum over it is short by those days. ' \
            "SOLECTRUS builds summaries on demand, at most #{MAX_DAYS} per " \
            'call: ask for a shorter timeframe, or open the SOLECTRUS web UI, ' \
            'to have the rest built.',
      }
    end
  end
end
