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
    TIMEFRAME_FORMS =
      '"2026-06-21" (a day), "2026-W25" (a week), "2026-06" (a month), ' \
        '"2026" (a year), "2026-01-01..2026-03-31" (a date range), ' \
        '"P24H"/"P30D"/"P12M" (a rolling window ending now), ' \
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

    # --- Sensors without a live reading -------------------------------------

    MONEY_ACCUMULATED =
      'Money sensors (costs, revenue) are accumulated amounts with no ' \
        'instantaneous reading - use get_totals over a timeframe.'.freeze

    CHART_ONLY =
      'Chart-only composites (e.g. power_balance) have no live scalar at all.'.freeze

    NON_AGGREGATABLE =
      'Boolean and string sensors (e.g. a car-connected flag, a status text) ' \
        'cannot be averaged into a time bucket at all - get_current_values ' \
        'reports their present state.'.freeze

    # Why get_totals and get_ranking reject a sensor outright instead of
    # answering null: both read a per-period value, and these sensors have
    # none to read. Stated as what the sensor IS, because no argument the
    # client could pass instead would help.
    NO_AGGREGATION =
      'They carry no aggregation at all (`aggregations: []` in ' \
        'get_sensor_details), so no per-period value exists and no ' \
        '`aggregation` argument can supply one. Use get_current_values for ' \
        'their present state, or get_series for their curve.'.freeze

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
        'get_totals or get_series over a timeframe that has ENDED - a past day ' \
        'is as exact as a year.'.freeze

    # --- Response conventions -----------------------------------------------

    UNKNOWN_SENSORS =
      'A name this instance does not have is skipped, not rejected: the rest ' \
        'is answered and the skipped names come back in `unknown_sensors`, so ' \
        'read that field instead of assuming all-or-nothing. Only a call with ' \
        'no valid name left fails.'.freeze

    ROUNDING =
      'Every value is rounded by its unit alone, identically in every tool; ' \
        'list_sensors publishes the decimals per unit in conventions.precision.'.freeze

    # The `tools` letter legend, derived from the matrix it describes so a
    # letter cannot be added to SupportedTools without appearing here. Only
    # `current` breaks the get_<flag> pattern.
    TOOL_NAMES = { current: 'get_current_values' }.freeze
    private_constant :TOOL_NAMES

    def self.tool_letters
      SupportedTools::LETTERS
        .map { |flag, letter| "#{letter} = #{TOOL_NAMES.fetch(flag, "get_#{flag}")}" }
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
                    :MONEY_ACCUMULATED,
                    :CHART_ONLY,
                    :NON_AGGREGATABLE,
                    :NO_AGGREGATION,
                    :SPLIT_CADENCE,
                    :SPLIT_INSTEAD,
                    :UNKNOWN_SENSORS,
                    :ROUNDING,
                    :TOOL_STRICTNESS
  end
end
