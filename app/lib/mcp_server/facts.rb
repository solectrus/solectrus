module McpServer
  # The handful of facts a model has to know to read a SOLECTRUS response
  # correctly, each stated exactly once.
  #
  # None of them belongs to a single tool: a power split behaves the same way in
  # get_current_values, get_series and list_sensors, and a summed watt is an
  # energy in get_totals and get_ranking alike. Before this module each fact was
  # written out again at every site that needed it - the splitter cadence in six
  # files, once as a comment and once as prose a few lines apart - so the same
  # sentence had six chances to drift and no canonical version to drift from.
  #
  # A tool description composes the facts it needs and adds only its own
  # consequence. A comment that would restate one references it instead.
  #
  # Each is phrased as tightly as the fact allows, because a canonical version
  # is paid for at every site that composes it: taking the longest of the
  # variants each one replaced cost ~650 bytes more across the tool
  # definitions, and that is context the client pays for in every session.
  module Facts
    # --- Timeframes ---------------------------------------------------------

    # Every `timeframe` spelling there is: the input schemas publish it up front
    # and Tools::Base.parse_timeframe repeats it when a client got it wrong
    # anyway. There are few enough forms to list them all, and listing them all
    # is the point - an "e.g." invites a model to extrapolate, and what it
    # extrapolates ("last-week", "yesterday", "2026-06-21..now") is never
    # accepted. A closed set leaves nothing to invent.
    #
    # The three P-forms are spelled out separately because only ONE of them
    # rolls. Timeframe#ending is Time.current for an hour window, but
    # yesterday's end of day for "PnD" and last month's for "PnM" - so "P30D"
    # is thirty whole days that stop before today, not the thirty days up to
    # this minute. Calling all three "a rolling window ending now" made a
    # client report a partial today inside a figure it had been told covers
    # the last 30 days, and contradicted the note get_totals sends for the
    # period still running.
    TIMEFRAME_FORMS =
      '"2026-06-21" (a day), "2026-W25" (a week), "2026-06" (a month), ' \
        '"2026" (a year), "2026-01-01..2026-03-31" (a date range), ' \
        '"P24H" (a rolling window ending NOW), "P30D" (30 WHOLE days, ending ' \
        'yesterday), "P12M" (12 WHOLE months, ending with last month) - ' \
        'neither of those two reaches into today, ' \
        '"day"/"week"/"month"/"year" (the current period), ' \
        '"all" (since installation)'.freeze

    # Why a timeframe can hold no data without any sensor being at fault.
    # Without it, a timeframe in the future and one before the system existed
    # both come back as a null value, indistinguishable from a sensor outage -
    # and a model reports "no data" where it should report "not yet" or "not
    # back then".
    TIMEFRAME_NOTE =
      'A timeframe that cannot hold data - entirely in the future, or ending ' \
        'before the installation date - still answers, but carries a ' \
        '`timeframe_note` saying which. Report that as "not yet" or "not back ' \
        'then", never "no data".'.freeze

    # --- Units --------------------------------------------------------------

    WATT_SUM_IS_ENERGY =
      'Summing a power sensor (unit "watt") yields an ENERGY, so the `value` ' \
        'is in Wh, not W (÷1000 for kWh) - never read a watt-sum as a power. ' \
        'All other units aggregate unchanged.'.freeze

    # Why the same day has two peaks, and why neither tool is wrong. The
    # summarizer aggregates min/max over 5-minute means rather than raw samples
    # (Sensor::Query::Helpers::Influx::Aggregation), so a spike shorter than
    # that window is averaged away before it can win. get_series reads the
    # samples themselves and finds it. On a measured day the two answered
    # 8800.6 W and 9536 W for the same sensor - 8 % apart, both correct, and
    # whichever tool the client happened to call decided the number. Each side
    # states it now, so a peak comes back qualified rather than reconciled
    # after the fact.
    SUMMARY_EXTREMES =
      'A summary min/max is the extreme of 5-minute MEANS, not of the raw ' \
        'samples, so a spike shorter than that is averaged away.'.freeze

    # --- Why a tool rejects a sensor ----------------------------------------
    #
    # None of these names a tool to ask instead. That half is composed per
    # sensor from SupportedTools.alternatives, because a fact is about the
    # sensor while the alternative is about the matrix - and a fact that
    # guessed at the matrix got it wrong: "use get_current_values or
    # get_series" sent a client asking for power_balance to two tools that
    # reject it as well.

    MONEY_ACCUMULATED =
      'Money sensors (costs, revenue) are accumulated amounts with no ' \
        'instantaneous reading.'.freeze

    # No example sensor here on purpose: the only place this appears names the
    # sensors it applies to, and "power_balance: Chart-only composites (e.g.
    # power_balance)" said the same name twice.
    CHART_ONLY =
      'A chart-only composite has no value of its own: it exists to feed a ' \
        'chart, which composes what it shows from other sensors.'.freeze

    NON_AGGREGATABLE =
      'Boolean and string sensors (e.g. a car-connected flag, a status text) ' \
        'cannot be averaged into a time bucket at all.'.freeze

    # Why get_totals and get_ranking reject a sensor outright instead of
    # answering null: both read a per-period value, and these sensors have
    # none to read. Stated as what the sensor IS, because no argument the
    # client could pass instead would help.
    NO_AGGREGATION =
      'Carries no aggregation at all (`aggregations: []` in ' \
        'get_sensor_details), so no per-period value exists and no ' \
        '`aggregation` argument can supply one.'.freeze

    # get_totals is measured actuals; a forecast has no place in a summary.
    FORECAST_NOT_MEASURED =
      'Holds predicted values, which the summaries of measured data do not ' \
        'carry.'.freeze

    # The second half of get_ranking's gate: a sensor CAN be aggregated and
    # still have nothing to rank, because the summaries do not store it.
    NOT_SUMMARIZED =
      'Derived from other sensors rather than stored in the summaries, so ' \
        'there is no per-period value to order by.'.freeze

    # --- Power splits (_grid/_pv) -------------------------------------------

    # The one fact that governs every split: it divides a period, not an
    # instant. Which is a statement about the Power Splitter's cadence, not
    # about how the sensor is spelled - see SplitSensors for the naming rule.
    SPLIT_CADENCE =
      'The Power Splitter writes one value per cycle of several minutes, so a ' \
        'split divides a PERIOD and never reads an instant.'.freeze

    # What to do instead, wherever the cadence rules a split out.
    SPLIT_INSTEAD =
      'Ask for the BASE sensor to read live power, and read the split with ' \
        'get_totals for any period that has ENDED, or with get_series for a ' \
        'past day - a past day is as exact as a year.'.freeze

    # --- Response conventions -----------------------------------------------

    UNKNOWN_SENSORS =
      'A name this instance does not have is skipped, not rejected: the rest ' \
        'is answered and the skipped names come back in `unknown_sensors`, so ' \
        'read that field instead of assuming all-or-nothing. Only a call with ' \
        'no valid name left fails.'.freeze

    # The shape get_series and get_ranking both return. Stated once, in the
    # server instructions, because it is the same shape in both and a client
    # only has to learn it once - and because spelling it out per tool cost
    # more than the format saves on a short call.
    COMPACT_AXIS =
      'A curve or ranking comes as an AXIS plus a bare `values` list, never ' \
        'as dated objects: values[i] sits at `start` + i steps, one step ' \
        'being `step_seconds` (get_series) or one `period` (get_ranking/get_periods). Two ' \
        'optional fields qualify it, each absent when it has nothing to say: ' \
        '`indices` gives the step offset of every value, and appears wherever ' \
        'they are not consecutive - without it, values[i] IS at offset i. ' \
        '`partial_at` NAMES the steps the window covers only partly, as the ' \
        'ISO period start (get_ranking/get_periods) or bucket end (get_series) `start` ' \
        'itself carries - never as a position, so it needs no index space. ' \
        'Such a step holds less than a full one: never read a flagged value ' \
        'as a low one. A null value means "no data", distinct from a ' \
        'measured 0.'.freeze

    ROUNDING =
      'Every value is rounded by its unit alone, identically in every tool; ' \
        'list_sensors publishes the decimals per unit in conventions.precision.'.freeze

    # The `tools` letter legend, derived from the matrix it describes so a
    # letter cannot be added to SupportedTools without appearing here.
    #
    # Two flags break the get_<flag> pattern: `current`, and `totals` - whose
    # single letter gates two tools, because get_periods is get_totals grouped
    # and answers for exactly the sensors it answers for. Naming both keeps
    # "t" from reading as a promise about one tool only, in the legend and in
    # every "use X instead" clause composed from the matrix.
    TOOL_NAMES = {
      current: 'get_current_values',
      totals: 'get_totals/get_periods',
    }.freeze
    private_constant :TOOL_NAMES

    # The public name of a tool flag. Every message that names a tool goes
    # through here, so the legend and the prose cannot drift apart.
    def self.tool_name(flag)
      TOOL_NAMES.fetch(flag, "get_#{flag}")
    end

    def self.tool_letters
      SupportedTools::LETTERS
        .map { |flag, letter| "#{letter} = #{tool_name(flag)}" }
        .join(', ')
    end

    # The half of the legend a client has to act on. Every letter is a
    # rejection rule; none is a promise, which is the one asymmetry a client
    # cannot derive from the matrix itself.
    TOOL_STRICTNESS =
      'A missing letter means that tool REJECTS the sensor. Its presence is ' \
        'no promise of a number: a value can still be null where the ' \
        "sensor's own calculation suppresses one.".freeze

    # Every fact is meant to be composed into a description elsewhere; that is
    # the whole purpose of the module.
    public_constant :TIMEFRAME_FORMS,
                    :TIMEFRAME_NOTE,
                    :WATT_SUM_IS_ENERGY,
                    :SUMMARY_EXTREMES,
                    :COMPACT_AXIS,
                    :MONEY_ACCUMULATED,
                    :CHART_ONLY,
                    :NON_AGGREGATABLE,
                    :NO_AGGREGATION,
                    :FORECAST_NOT_MEASURED,
                    :NOT_SUMMARIZED,
                    :SPLIT_CADENCE,
                    :SPLIT_INSTEAD,
                    :UNKNOWN_SENSORS,
                    :ROUNDING,
                    :TOOL_STRICTNESS
  end
end
