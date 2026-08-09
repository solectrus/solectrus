describe McpServer::Tools::Series do
  def call(**args)
    response = described_class.call(**args)
    [response.error?, response.content.first[:text]]
  end

  def series(**args)
    _error, text = call(**args)
    data = JSON.parse(text, symbolize_names: true)
    data[:series]&.each { |entry| entry[:points] = expand(entry) }
    data
  end

  # Rebuilds the {time, value} list the compact axis describes - exactly the
  # arithmetic a client performs. It keeps the behavioural expectations below
  # about behaviour rather than about serialization, and doubles as an
  # executable statement of what `start`/`step_seconds`/`indices`/`partial_at`
  # mean. The format itself is pinned separately, further down.
  def expand(entry)
    start = Time.zone.parse(entry[:start].to_s)
    step = entry[:step_seconds]
    partial = entry[:partial_at] || []

    entry[:values].each_with_index.map do |value, i|
      index = entry[:indices] ? entry[:indices][i] : i
      time = (start + (index * step)).iso8601

      { time:, value:, **(partial.include?(time) ? { partial: true } : {}) }
    end
  end

  before { freeze_time }

  # The description enumerates the constraints that coarsen a request, and a
  # client acts on that enumeration: it decides whether to shorten a timeframe
  # or to accept the answer. It said "exactly two things" long after the
  # splitter cycle became a third, so a `coarsened_reason` naming the Power
  # Splitter matched no rule the client had been given.
  describe '.description' do
    # Each cause Resolution.explain can report, with the word the description
    # has to carry for a client to recognise it in the answer.
    {
      point_budget: 'budget',
      forecast_window: 'forecast',
      splitter_cycle: 'Power Splitter',
    }.each do |cause, word|
      it "names the #{cause} constraint" do
        explained =
          McpServer::Tools::Series::Resolution.explain(cause, '1m', '5m', 1)

        expect(explained[:coarsened_reason]).to be_present
        expect(described_class.description).to include(word)
      end
    end

    it 'counts them correctly' do
      expect(described_class.description.squish).to include('three things')
    end

    # `partial_at` is sent on every running window and on every rolling one,
    # so it is the field a client meets first. Unnamed in the description it
    # arrives as a bare list of timestamps, and the value it flags reads as a
    # low measurement rather than as a bucket the window only cuts into.
    it 'names `partial_at` and what it names' do
      description = described_class.description.squish

      expect(description).to include('`partial_at`')
      expect(description).to include('bucket END')
      expect(description).to include('never read it as a low one')
    end
  end

  describe '.call' do
    context 'with measured data and a gap' do
      before do
        influx_batch do
          # A measured 0 (e.g. battery empty) ...
          add_influx_point(
            name: Sensor::Config.measurement(:battery_soc),
            fields: {
              Sensor::Config.field(:battery_soc) => 0.0,
            },
            time: 150.minutes.ago,
          )
          # ... and a real value two hours later, leaving an empty bucket between.
          add_influx_point(
            name: Sensor::Config.measurement(:battery_soc),
            fields: {
              Sensor::Config.field(:battery_soc) => 50.0,
            },
            time: 30.minutes.ago,
          )
        end
      end

      it 'distinguishes a measured 0 from null (no data)' do
        data = series(sensors: ['battery_soc'], timeframe: 'P3H', resolution: '1h')

        values = data[:series].first[:points].pluck(:value)
        expect(values).to include(0.0) # measured zero is kept
        expect(values).to include(nil) # empty bucket stays null
      end

      it 'returns points in chronological order' do
        data = series(sensors: ['battery_soc'], timeframe: 'P3H', resolution: '1h')

        times = data[:series].first[:points].map { |p| Time.iso8601(p[:time]) }
        expect(times).to eq(times.sort)
      end
    end

    context 'with the timestamp of a bucket' do
      let(:day) { (Date.current - 1.day).to_s }
      let(:sample) { (Date.current - 1.day).beginning_of_day + 7.hours + 3.minutes }

      before do
        add_influx_point(
          name: Sensor::Config.measurement(:battery_soc),
          fields: {
            Sensor::Config.field(:battery_soc) => 55.0,
          },
          time: sample,
        )
      end

      # The `time` of a point is the END of its bucket, so a sample at 07:03
      # is reported at 07:05 with 5m buckets - not at 07:00. Without this being
      # documented, a client has to rediscover it by cross-checking get_totals.
      it 'labels a bucket with its end' do
        points =
          series(
            sensors: ['battery_soc'],
            timeframe: day,
            resolution: '5m',
            include_nulls: false,
          ).dig(:series, 0, :points)

        expect(points.pluck(:time)).to eq(
          [(sample.beginning_of_hour + 5.minutes).iso8601],
        )
      end

      # Buckets follow the installation's timezone, so a local day starts and
      # ends at local midnight. Aligned to UTC it used to be cut elsewhere,
      # which reads like lost data when compared against get_totals.
      it 'covers a local day with 24 hourly buckets' do
        points =
          series(sensors: ['battery_soc'], timeframe: day, resolution: '1h')
            .dig(:series, 0, :points)

        expect(points.size).to eq(24)
        expect(Time.iso8601(points.first[:time])).to eq(
          Date.parse(day).beginning_of_day + 1.hour,
        )
      end

      # aggregateWindow clips the last bucket at the query's range stop, which
      # is the last nanosecond of the day and reaches Flux as 23:59:59. So the
      # closing point used to sit one second off the grid every other point is
      # on - at 1h a day read 01:00, ..., 23:00, 23:59:59, which a client can
      # only take for a bucket of its own.
      it 'closes the last bucket of a day at the next midnight, not 23:59:59' do
        points =
          series(sensors: ['battery_soc'], timeframe: day, resolution: '1h')
            .dig(:series, 0, :points)

        expect(points.last[:time]).to eq(
          Date.parse(day).tomorrow.beginning_of_day.iso8601,
        )
      end

      # Every point sits on the same grid, so the closing one has to as well -
      # including the one that closes a day inside the range rather than the
      # range itself.
      it 'keeps every point on the bucket grid' do
        points =
          series(
            sensors: ['battery_soc'],
            timeframe: "#{day}..#{Date.current}",
            resolution: '1h',
          ).dig(:series, 0, :points)

        times = points.map { Time.iso8601(_1[:time]).strftime('%M:%S') }
        times.uniq!

        expect(times).to eq(['00:00'])
      end
    end

    # Regression: forecast samples are shifted back by half the provider's
    # cadence to align them with live sensors, and that shift moved the query
    # window's end along with them. A request for forecast sensors ALONE then
    # ended its last bucket half a window early - 23:52:29 instead of 23:59:59
    # for a 15m provider - while the same request with a live sensor added ended
    # correctly. Both must carry the end of the requested timeframe.
    context 'with the last bucket of the timeframe' do
      let(:day) { (Date.current - 1.day).to_s }
      let(:closing) { Date.parse(day).tomorrow.beginning_of_day }

      before do
        influx_batch do
          96.times do |i|
            time = (Date.current - 1.day).beginning_of_day + (i * 15).minutes
            add_influx_point(
              name: Sensor::Config.measurement(:inverter_power_forecast),
              fields: {
                Sensor::Config.field(:inverter_power_forecast) => i + 1000.0,
              },
              time:,
            )
          end

          288.times do |i|
            add_influx_point(
              name: Sensor::Config.measurement(:house_power),
              fields: {
                Sensor::Config.field(:house_power) => i + 500.0,
              },
              time: (Date.current - 1.day).beginning_of_day + (i * 5).minutes,
            )
          end
        end
      end

      def last_time(sensors)
        points = series(sensors:, timeframe: day, resolution: '1h').dig(:series, 0, :points)
        Time.iso8601(points.last[:time])
      end

      it 'ends a forecast-only series at the end of the timeframe' do
        expect(last_time(['inverter_power_forecast'])).to eq(closing)
      end

      it 'ends a measured series at the end of the timeframe' do
        expect(last_time(['house_power'])).to eq(closing)
      end

      it 'ends every series of a mixed request at the same bucket' do
        data =
          series(
            sensors: %w[house_power inverter_power_forecast],
            timeframe: day,
            resolution: '1h',
          )

        last_times = data[:series].map { |s| s[:points].last[:time] }
        expect(last_times.uniq).to eq([closing.iso8601])
      end

      # A day that has ended is measured all the way through, so nothing in it
      # is a fragment. Timeframe#ending is its last NANOSECOND, which the
      # closing bucket compares as reaching past - and briefly did, marking
      # every completed day's last hour as incomplete.
      it 'marks no bucket of a completed day as partial' do
        points = series(sensors: ['house_power'], timeframe: day, resolution: '1h').dig(:series, 0, :points)

        expect(points.select { _1[:partial] }).to be_empty
      end

      # The wire format itself, which every other example reads through
      # `expand`. Pinned here so a change to the shape fails loudly rather than
      # silently teaching the helper a new one.
      describe 'the compact axis' do
        def entry(**args)
          _error, text =
            call(sensors: ['house_power'], timeframe: day, resolution: '1h', **args)
          JSON.parse(text, symbolize_names: true).dig(:series, 0)
        end

        it 'states the axis once and sends values as bare scalars' do
          data = entry

          expect(data[:start]).to eq((Date.parse(day).beginning_of_day + 1.hour).iso8601)
          expect(data[:step_seconds]).to eq(3600)
          expect(data[:point_count]).to eq(24)
          expect(data[:values].size).to eq(24)
          expect(data[:values]).to all(satisfy { _1.nil? || _1.is_a?(Numeric) })
        end

        # The whole point of the format: with a full grid, position IS index,
        # so nothing has to be sent to say so.
        it 'omits indices where the buckets are consecutive' do
          expect(entry).not_to have_key(:indices)
        end

        it 'omits partial_at where no bucket is cut' do
          expect(entry).not_to have_key(:partial_at)
        end

        # The timeframe and the resolution fix the grid, so an empty curve
        # still knows where it would have started. Without the axis, `values:
        # []` is the one response a client cannot interpret - and it would
        # force a special case on the reader for the case that needs it least.
        it 'states the axis even when no bucket carried a value' do
          data = entry(sensors: ['heatpump_power'])

          expect(data[:point_count]).to eq(0)
          expect(data[:values]).to be_empty
          expect(data[:start]).to be_present
          expect(data[:step_seconds]).to eq(3600)
        end
      end
    end

    # An implicit axis puts the daylight-saving arithmetic on the client, where
    # a timestamp per point used to carry it. `step_seconds` counts REAL
    # seconds, so the axis stays correct - but only for a client that converts
    # to local time rather than carrying the offset in `start` forward.
    context 'with a day that crosses a daylight-saving switch' do
      # Every half hour, so each bucket of either day carries a value and the
      # point count reflects the day's length rather than where data happens
      # to stop.
      def seed(day)
        influx_batch do
          52.times do |i|
            add_influx_point(
              name: Sensor::Config.measurement(:battery_soc),
              fields: {
                Sensor::Config.field(:battery_soc) => 50.0,
              },
              time: Date.parse(day).beginning_of_day + (i * 30).minutes,
            )
          end
        end
      end

      def local_hours(day)
        seed(day)
        entry = series(sensors: ['battery_soc'], timeframe: day, resolution: '1h').dig(:series, 0)
        start = Time.zone.parse(entry[:start])

        (0...entry[:point_count]).map { (start + (it * entry[:step_seconds])).in_time_zone.hour }
      end

      # 02:00 never happens, so the day is an hour short.
      it 'holds 23 points on the short day, skipping the hour that does not exist' do
        hours = local_hours('2026-03-29')

        expect(hours.size).to eq(23)
        expect(hours.first(3)).to eq([1, 3, 4])
      end

      # 02:00 happens twice, so the day is an hour long.
      it 'holds 25 points on the long day, repeating the hour that happens twice' do
        hours = local_hours('2025-10-26')

        expect(hours.size).to eq(25)
        expect(hours.first(4)).to eq([1, 2, 2, 3])
      end
    end

    # Dropping the empty buckets breaks "values[i] is at index i", so the kept
    # ones have to carry their grid position - otherwise a sporadically written
    # sensor comes back as a dense curve with every value at the wrong time.
    context 'with empty buckets dropped from a sparse sensor' do
      let(:day) { (Date.current - 1.day).to_s }

      before do
        influx_batch do
          [1, 5, 6, 20].each do |hour|
            add_influx_point(
              name: Sensor::Config.measurement(:battery_soc),
              fields: {
                Sensor::Config.field(:battery_soc) => hour + 40.0,
              },
              time: Date.parse(day).beginning_of_day + hour.hours + 30.minutes,
            )
          end
        end
      end

      def entry(**args)
        _error, text =
          call(sensors: ['battery_soc'], timeframe: day, resolution: '1h', **args)
        JSON.parse(text, symbolize_names: true).dig(:series, 0)
      end

      it 'sends the grid position of every kept value' do
        data = entry(include_nulls: false)

        expect(data[:values]).not_to include(nil)
        expect(data[:indices].size).to eq(data[:values].size)
        ascending = data[:indices].uniq
        ascending.sort!
        expect(data[:indices]).to eq(ascending)
        expect(data[:indices]).not_to eq((0...data[:values].size).to_a)
      end

      # The dropped form has to describe the same curve as the full one, or the
      # saving is a lie. This is the arithmetic a client does, checked against
      # the answer that spells every bucket out.
      it 'describes the same curve as the full grid' do
        sparse = entry(include_nulls: false)
        full = entry(include_nulls: true)

        placed =
          sparse[:indices].zip(sparse[:values]).to_h
        rebuilt =
          (0...full[:values].size).map { placed[it] }

        expect(rebuilt).to eq(full[:values])
        expect(sparse[:start]).to eq(full[:start])
      end
    end

    # aggregateWindow clips its final bucket at the range stop, so the last
    # point of a running window used to arrive off the grid every other point
    # sits on ("05:00, 06:00, 06:44:29") - which a client reading the points as
    # a raster can only take for a bucket of its own.
    context 'with a window that opens and closes mid-bucket' do
      # Every minute, so each bucket the window touches carries a value -
      # including the sliver of the opening one that lies inside it. An empty
      # bucket is deliberately never marked partial, so a gap there would test
      # the wrong thing.
      before do
        influx_batch do
          240.times do |i|
            add_influx_point(
              name: Sensor::Config.measurement(:house_power),
              fields: {
                Sensor::Config.field(:house_power) => i + 100.0,
              },
              time: Time.current.beginning_of_hour - 3.hours + i.minutes,
            )
          end
        end
      end

      def points
        series(sensors: ['house_power'], timeframe: 'P2H', resolution: '1h').dig(:series, 0, :points)
      end

      it 'puts every point on the grid' do
        off_grid = points.reject { Time.iso8601(_1[:time]).min.zero? }

        expect(off_grid).to be_empty
      end

      # Both edges get cut, and the opening one is the easier to misread: it
      # sits at the start of the curve, where a client looks for a baseline.
      it 'marks both cut edges as partial, and nothing between them' do
        flagged = points.map { _1[:partial] == true }

        expect(flagged.first).to be(true)
        expect(flagged.last).to be(true)
        expect(flagged[1..-2]).to all(be(false))
      end

      # By bucket END, the label `start` carries - not by position in `values`.
      # A position would be a second index space beside `indices`, which counts
      # STEPS, and nothing in the response says which one a reader is holding.
      it 'names the cut buckets the way the axis names its own' do
        _error, text = call(sensors: ['house_power'], timeframe: 'P2H', resolution: '1h')
        entry = JSON.parse(text, symbolize_names: true).dig(:series, 0)
        start = Time.zone.parse(entry[:start])
        last = start + ((entry[:values].size - 1) * entry[:step_seconds])

        expect(entry[:partial_at]).to eq([start.iso8601, last.iso8601])
      end
    end

    # The period still running: "day" nominally ends at midnight, so the bucket
    # holding the current hour compares as complete against that bound while it
    # is half over.
    context 'with the period still running' do
      before do
        influx_batch do
          add_influx_point(
            name: Sensor::Config.measurement(:house_power),
            fields: {
              Sensor::Config.field(:house_power) => 500.0,
            },
            time: Time.current.beginning_of_hour + 1.minute,
          )
        end
      end

      it 'marks the current bucket but not the empty ones ahead of it' do
        points = series(sensors: ['house_power'], timeframe: 'day', resolution: '1h').dig(:series, 0, :points)
        flagged = points.select { _1[:partial] }

        expect(flagged.size).to eq(1)
        expect(flagged.first[:value]).not_to be_nil
        expect(points.select { _1[:value].nil? && _1[:partial] }).to be_empty
      end
    end

    context 'with resolution selection' do
      let(:budget) { McpServer::Tools::Series::Resolution::MAX_POINTS }

      it 'auto-selects a resolution within the point limit' do
        data = series(sensors: ['battery_soc'], timeframe: 'P72H')

        expect(data[:resolution]).to be_in(McpServer::Tools::Series::Resolution::LABELS)
        expect(data[:series].first[:points].size).to be <= budget
      end

      it 'coarsens a too-fine resolution and reports the one actually used' do
        data = series(sensors: ['battery_soc'], timeframe: 'P48H', resolution: '1m')

        expect(data[:resolution]).not_to eq('1m')
        expect(data[:series].first[:points].size).to be <= budget
      end

      # The canonical fine request - one sensor over one day at the finest
      # bucket - is exactly what the budget is sized around: 1440 points, not
      # one step coarser. It used to land on 5m, because the budget was still
      # priced for a point that carried its own ISO timestamp.
      it 'keeps a single sensor over a day at 1m' do
        data = series(sensors: ['battery_soc'], timeframe: (Date.current - 1).to_s)

        expect(data[:resolution]).to eq('1m')
      end

      it 'keeps a resolution that already fits' do
        data = series(sensors: ['battery_soc'], timeframe: 'P24H', resolution: '1h')

        expect(data[:resolution]).to eq('1h')
      end

      it 'reports coarsened: false when the requested resolution is kept' do
        data = series(sensors: ['battery_soc'], timeframe: 'P24H', resolution: '1h')

        expect(data[:coarsened]).to be(false)
      end

      it 'omits the reason when nothing was coarsened' do
        data = series(sensors: ['battery_soc'], timeframe: 'P24H', resolution: '1h')

        expect(data).not_to have_key(:coarsened_reason)
      end

      it 'reports coarsened: true when a too-fine resolution is downgraded' do
        data = series(sensors: ['battery_soc'], timeframe: 'P48H', resolution: '1m')

        expect(data[:coarsened]).to be(true)
      end

      # A bare boolean leaves a client guessing what to change. Name the
      # constraint and the lever.
      it 'names the point budget as the reason and what to change' do
        data = series(sensors: ['battery_soc'], timeframe: 'P48H', resolution: '1m')

        expect(data[:coarsened_reason]).to include('1m', budget.to_s, 'shorter timeframe')
      end

      it 'reports the point count per series' do
        data = series(sensors: ['battery_soc'], timeframe: 'P24H', resolution: '1h')

        series_entry = data[:series].first
        expect(series_entry[:point_count]).to eq(series_entry[:points].size)
      end
    end

    context 'with the point budget shared across multiple sensors' do
      # The budget is global, not per sensor: three sensors over a day at 5m
      # would be 864 points, so the resolution coarsens until the WHOLE payload
      # fits - what reaches the client is one context window, not three.
      let(:sensors) { %w[house_power inverter_power grid_import_power] }
      let(:day) { Date.current.to_s }
      let(:budget) { McpServer::Tools::Series::Resolution::MAX_POINTS }

      it 'coarsens so the total point count stays within the cap' do
        data = series(sensors:, timeframe: day)

        expect(data[:series].sum { |s| s[:point_count] }).to be <= budget
      end

      it 'does not keep 1m for three sensors on a single day' do
        data = series(sensors:, timeframe: day, resolution: '1m')

        expect(data[:resolution]).not_to eq('1m')
        expect(data[:coarsened]).to be(true)
      end

      it 'names the sensor count in the reason' do
        data = series(sensors:, timeframe: day, resolution: '1m')

        expect(data[:coarsened_reason]).to include('3 sensor(s)')
      end
    end

    # get_series reads the raw InfluxDB samples, which is what makes it the
    # intraday tool and nothing more: a bucket holds the mean of its samples,
    # while the PostgreSQL summaries hold an exact figure per period. From a
    # week upwards the question is theirs.
    #
    # Without a cap the tool answered "all" with 2080 points - and
    # coarsened: false, because nothing HAD been coarsened: the ladder had run
    # out at "1d" and fell back to it unchecked. That one response was larger
    # than every other call of the session together, and it grows by a point a
    # day.
    context 'with a timeframe longer than the tool answers' do
      let(:max_hours) { McpServer::Tools::Series::MAX_SPAN.in_hours.to_i }

      def rejects?(timeframe, sensors: ['battery_soc'])
        call(sensors:, timeframe:).first
      end

      it 'rejects a rolling month' do
        expect(rejects?('P30D')).to be(true)
      end

      it 'rejects the whole installation history' do
        expect(rejects?('all')).to be(true)
      end

      it 'rejects a calendar week, month and year' do
        expect(%w[week 2024-06 2024].map { rejects?(_1) }).to eq([true, true, true])
      end

      it 'names the limit and the tools that answer instead' do
        _error, text = call(sensors: ['battery_soc'], timeframe: 'P30D')

        expect(text).to include("#{max_hours} hours", 'get_totals', 'get_ranking')
      end

      # The UI offers 72 hours at most, but the data does not stop there and
      # neither does the timeframe grammar, whose hour window runs to P99H.
      it 'answers the longest hour window the grammar states' do
        expect(rejects?("P#{max_hours}H")).to be(false)
      end

      # Four days is the longest date range that fits, and it stays four days
      # across a daylight-saving switch - which a bound of 72 hours would not
      # have.
      it 'answers a four-day range and rejects a five-day one' do
        four = "#{(Date.current - 3).iso8601}..#{Date.current.iso8601}"
        five = "#{(Date.current - 4).iso8601}..#{Date.current.iso8601}"

        expect([rejects?(four), rejects?(five)]).to eq([false, true])
      end

      # A forecast horizon is the provider's, not a measurement, and no summary
      # holds it - so there is nothing to send the client to and the cap does
      # not apply.
      it 'exempts a forecast-only request' do
        expect(rejects?('P7D', sensors: ['inverter_power_forecast'])).to be(false)
      end

      it 'does not exempt a forecast sensor riding along with a measured one' do
        expect(
          rejects?('P7D', sensors: %w[house_power inverter_power_forecast]),
        ).to be(true)
      end
    end

    # The budget outlives the timeframe cap, because "1h" over a window the cap
    # allows can still cost more than the sensors sharing it may spend.
    context 'with a request the point budget cannot carry at 1h' do
      let(:budget) { McpServer::Tools::Series::Resolution::MAX_POINTS }

      # 99 hours at "1h" is 99 points per sensor, so the request tips over once
      # the share falls below that - at 15 sensors, which get 96 each.
      let(:sensors) do
        %w[
          house_power
          inverter_power
          grid_import_power
          grid_export_power
          battery_soc
          heatpump_power
          wallbox_power
          heatpump_tank_temp
          outdoor_temp
          case_temp
          battery_power
          grid_power
          total_consumption
          self_consumption
          inverter_power_total
        ]
      end

      it 'rejects rather than answering over budget' do
        error, = call(sensors:, timeframe: 'P99H')

        expect(error).to be(true)
      end

      it 'names the share and the two levers' do
        _error, text = call(sensors:, timeframe: 'P99H')

        expect(text).to include(
          "#{budget} shared by #{sensors.size} sensors",
          'fewer sensors',
        )
      end

      it 'answers the same sensors over a shorter window' do
        error, = call(sensors:, timeframe: 'P24H')

        expect(error).to be(false)
      end

      # The one request that reaches the budget with a single sensor: a
      # forecast, which the timeframe cap lets through.
      it 'points a long forecast request at get_forecast' do
        _error, text = call(sensors: ['inverter_power_forecast'], timeframe: 'P12M')

        expect(text).to include('get_forecast')
      end
    end

    # A running day spans 24 hours no matter what time it is, but the buckets
    # still ahead cannot carry a point. With include_nulls: false they are
    # dropped before the client sees them, so charging the budget for them
    # coarsened the answer for points that were never sent: three sensors over
    # today fell from 5m to 1h at breakfast and recovered by midnight.
    context 'with the running day and include_nulls: false' do
      let(:sensors) { %w[house_power inverter_power grid_import_power] }

      # 08:00 - a third of the day gone, two thirds of the buckets empty.
      before { travel_to Time.zone.now.beginning_of_day + 8.hours }

      def resolution(**args)
        series(sensors:, timeframe: Date.current.to_s, **args)[:resolution]
      end

      it 'does not charge the budget for buckets that lie ahead' do
        expect(resolution(include_nulls: false)).to eq('1m')
      end

      it 'still charges for them when the empty buckets are returned' do
        expect(resolution(include_nulls: true)).to eq('5m')
      end

      it 'keeps the whole span for a forecast sensor, whose future buckets carry values' do
        data =
          series(
            sensors: ['inverter_power_forecast'],
            timeframe: Date.current.to_s,
            include_nulls: false,
          )

        expect(data[:resolution]).to eq('15m')
      end

      # The budget is a context-window budget, so dropping the empty tail must
      # not let the response through it.
      it 'stays within the point budget' do
        data =
          series(sensors:, timeframe: Date.current.to_s, include_nulls: false)

        expect(data[:series].sum { _1[:point_count] }).to be <=
          McpServer::Tools::Series::Resolution::MAX_POINTS
      end
    end

    # A curve is a sequence of periods, and a power split divides periods - it
    # only cannot divide an instant. So a split keeps its curve, under the two
    # conditions the `s` flag cannot carry: the window has to be over, and the
    # bucket cannot be finer than the Power Splitter's cycle.
    context 'with a power split' do
      let(:day) { (Date.current - 1.day).to_s }

      before do
        stub_feature(:power_splitter)

        influx_batch do
          288.times do |i|
            add_influx_point(
              name: Sensor::Config.measurement(:house_power_grid),
              fields: {
                Sensor::Config.field(:house_power_grid) => 400.0,
              },
              time: (Date.current - 1.day).beginning_of_day + (i * 5).minutes,
            )
          end
        end
      end

      it 'answers over a day that has ended' do
        data = series(sensors: ['house_power_grid'], timeframe: day)

        expect(data[:series].first[:points].pluck(:value).compact).to all(eq(400.0))
      end

      it 'rejects the running day, whose newest buckets have no split yet' do
        error, text = call(sensors: ['house_power_grid'], timeframe: Date.current.to_s)

        expect(error).to be(true)
        expect(text).to include('ENDED', 'house_power_grid')
      end

      it 'rejects a rolling window that ends now' do
        error, = call(sensors: ['house_power_grid'], timeframe: 'P24H')

        expect(error).to be(true)
      end

      # Below the splitter cycle most buckets are empty by construction, which
      # reads as an outage rather than as the cadence it is.
      #
      # Today the point budget already caps a whole day at 5m, so the floor
      # changes no outcome on its own - the shortest window get_series answers
      # for a split is a full past day. It is raised here to show the floor
      # holds independently, because a budget is a context-window decision that
      # can move, while the splitter cadence is physical.
      it 'never answers finer than the splitter cycle' do
        stub_const("#{McpServer::Tools::Series::Resolution}::MAX_POINTS", 2_000)

        data =
          series(sensors: ['house_power_grid'], timeframe: day, resolution: '1m')

        expect(data[:resolution]).to eq('5m')
        expect(data[:coarsened_reason]).to include('Power Splitter')
      end

      it 'lets an ordinary sensor go finer under the same budget' do
        stub_const("#{McpServer::Tools::Series::Resolution}::MAX_POINTS", 2_000)

        data = series(sensors: ['house_power'], timeframe: day, resolution: '1m')

        expect(data[:resolution]).to eq('1m')
      end

      # At the real budget both constraints land on 5m: a day at 1m is 1440
      # points (over the 400 budget) and the splitter cycle floors at 5m
      # anyway. Naming the budget there is advice a client cannot act on - it
      # shortens the timeframe as told and still gets 5m, because the floor was
      # the binding constraint all along. So where the floor is what the answer
      # rests on, the floor is what gets named.
      it 'names the splitter cycle, not the budget, when both bind' do
        data =
          series(sensors: ['house_power_grid'], timeframe: day, resolution: '1m')

        expect(data[:resolution]).to eq('5m')
        expect(data[:coarsened_reason]).to include('Power Splitter')
        expect(data[:coarsened_reason]).not_to include('Request fewer sensors')
      end

      # One densely written sensor in the request lifts the floor - the same
      # rule the forecast floor follows.
      #
      # Only the FLOOR, though: the second sensor also halves the shared point
      # budget, and at the shipped budget that costs more than the floor gave.
      # So the budget is raised far enough to isolate the floor, the way the
      # spec above does. Asserting this at the shipped budget is what let the
      # earlier version of this example pass on 15m - coarser than the 5m the
      # split gets alone, and the opposite of what it claims to show.
      it 'lifts the floor when a base sensor rides along' do
        stub_const("#{McpServer::Tools::Series::Resolution}::MAX_POINTS", 4_000)

        data =
          series(
            sensors: %w[house_power house_power_grid],
            timeframe: day,
            resolution: '1m',
          )

        expect(data[:resolution]).to eq('1m')
      end

      # The flip side, and why the advice to "add the base sensor" is gone from
      # the tool: adding one never buys a finer grid. It cannot, whichever
      # constraint binds - the splitter floor holds the split at 5m on its own,
      # and a second sensor only ever halves the shared budget.
      it 'does not go finer for a base sensor at the shipped budget' do
        alone = series(sensors: %w[house_power_grid], timeframe: day, resolution: '1m')
        paired =
          series(
            sensors: %w[house_power house_power_grid],
            timeframe: day,
            resolution: '1m',
          )

        expect(alone[:resolution]).to eq('5m')
        expect(paired[:resolution]).to eq('5m')
      end

      # The _pv half is computed here, in the InfluxDB path, which applies no
      # clamp of its own - the summary and chart layers that do are not
      # involved. So a grid half written above the base sensor it divides used
      # to leave the tool reporting a negative solar share, a value the sensor
      # declares impossible. The declared range now floors every calculate
      # result (spec/lib/sensor/definitions/dsl_spec.rb); this pins that the
      # floor reaches the series a client actually reads.
      it 'reports no negative solar share when the grid half exceeds the base' do
        influx_batch do
          288.times do |i|
            add_influx_point(
              name: Sensor::Config.measurement(:house_power),
              fields: {
                Sensor::Config.field(:house_power) => 100.0,
              },
              time: (Date.current - 1.day).beginning_of_day + (i * 5).minutes,
            )
          end
        end

        values = series(sensors: ['house_power_pv'], timeframe: day)[:series]
          .first[:points]
          .pluck(:value)
          .compact

        expect(values).not_to be_empty
        expect(values).to all(eq(0.0))
      end
    end

    context 'with a resolution finer than a forecast window' do
      # Forecast providers carry one sample per 15 minutes at the finest. The
      # point budget alone would settle on 5m for a single day, and 2 of every
      # 3 buckets would be null - so the forecast cadence puts its own floor
      # under the resolution, independent of the budget.
      let(:day) { (Date.current + 1.day).to_s }

      before do
        influx_batch do
          96.times do |i|
            time = (Date.current + 1.day).beginning_of_day + (i * 15).minutes
            add_influx_point(
              name: Sensor::Config.measurement(:inverter_power_forecast),
              fields: {
                Sensor::Config.field(:inverter_power_forecast) =>
                  (8...16).cover?(time.hour) ? 1000 : 0,
              },
              time:,
            )
          end
        end
      end

      it 'lifts the resolution to the forecast window and reports it' do
        data =
          series(
            sensors: ['inverter_power_forecast'],
            timeframe: day,
            resolution: '1m',
          )

        expect(data[:resolution]).to eq('15m')
      end

      it 'does not return a mostly-null series' do
        data =
          series(
            sensors: ['inverter_power_forecast'],
            timeframe: day,
            resolution: '1m',
          )

        points = data[:series].first[:points]
        non_null = points.count { |p| !p[:value].nil? }

        # At 1m this would be ~96/1440 (7%); at 15m nearly every bucket carries
        # a value.
        expect(points.size).to be < 200
        expect(non_null.fdiv(points.size)).to be > 0.8
      end

      # The forecast cadence is not a budget that can be traded against, so the
      # reason must not tell the client to ask for fewer sensors.
      it 'names the forecast window as the reason, not the budget' do
        data =
          series(
            sensors: ['inverter_power_forecast'],
            timeframe: day,
            resolution: '1m',
          )

        expect(data[:coarsened_reason]).to include('forecast providers')
        expect(data[:coarsened_reason]).not_to include('fewer')
      end
    end

    # Regression: an event-based sensor (a coffee machine writing only on load
    # change) had its cadence estimated from the aggregated grid. That estimate
    # grew with the bucket size - samples merge, gaps widen - so the coarser
    # the request, the coarser the estimate and the coarser the answer: 5m came
    # back as 5m, but 15m and 1h both collapsed into 1d.
    context 'with a sparse, event-based sensor' do
      let(:day) { (Date.current - 1.day).to_s }
      let(:resolutions) { %w[1m 5m 15m 1h] }
      # Six brew cycles spread over the day, each written as two points (on,
      # off) four minutes apart.
      let(:brews) { [7.hours, 7.hours + 20.minutes, 9.hours, 12.hours + 30.minutes, 15.hours + 10.minutes, 18.hours] }
      let(:cycle) { { 0.minutes => 1312.3, 4.minutes => 0.0 } }

      before do
        base = (Date.current - 1.day).beginning_of_day

        influx_batch do
          brews.each do |offset|
            cycle.each do |delay, value|
              add_influx_point(
                name: Sensor::Config.measurement(:custom_power_12),
                fields: {
                  Sensor::Config.field(:custom_power_12) => value,
                },
                time: base + offset + delay,
              )
            end
          end
        end
      end

      def resolution_for(requested)
        series(
          sensors: ['custom_power_12'],
          timeframe: day,
          resolution: requested,
        )[:resolution]
      end

      it 'never answers a coarser request with a coarser resolution' do
        # The invariant a client relies on: asking for a coarser bucket can
        # never come back finer than asking for a finer one. Which resolutions
        # survive verbatim depends on the point budget (a day at 1m is 1440
        # points and does not fit), the ordering does not.
        answered =
          resolutions.map { |requested| resolutions.index(resolution_for(requested)) }

        expect(answered).to eq(answered.sort)
      end

      it 'honours every resolution that fits the point budget' do
        expect(%w[5m 15m 1h].map { |requested| resolution_for(requested) }).to eq(%w[5m 15m 1h])
      end

      it 'returns the full grid including empty buckets by default' do
        points =
          series(
            sensors: ['custom_power_12'],
            timeframe: day,
            resolution: '15m',
          ).dig(:series, 0, :points)

        expect(points.size).to eq(96)
        expect(points.pluck(:value)).to include(nil)
      end

      it 'omits exactly the empty buckets with include_nulls: false' do
        args = { sensors: ['custom_power_12'], timeframe: day, resolution: '15m' }
        full = series(**args).dig(:series, 0, :points)
        compact = series(**args, include_nulls: false).dig(:series, 0, :points)

        # Same points, same timestamps - only the empty ones are gone.
        expect(compact).to eq(full.reject { |point| point[:value].nil? })
        expect(compact.size).to eq(6)
      end

      it 'keeps every event visible at the resolution it returns' do
        points =
          series(
            sensors: ['custom_power_12'],
            timeframe: day,
            resolution: '15m',
          ).dig(:series, 0, :points)

        expect(points.count { |point| !point[:value].nil? }).to eq(6)
      end
    end

    context 'with multiple sensors' do
      it 'returns one series per sensor' do
        data =
          series(
            sensors: %w[battery_soc house_power],
            timeframe: 'P6H',
            resolution: '1h',
          )

        expect(data[:series].pluck(:sensor)).to eq(%w[battery_soc house_power])
      end
    end

    # Regression: derived sensors (computed, not stored as a raw field) used to
    # return an empty series. inverter_power_total = inverter_power_1 +
    # inverter_power_2 is derived the same way as house_power_without_custom.
    context 'with a derived (calculated) sensor' do
      def seed_inverters(value1:, value2:, from:)
        influx_batch do
          (0..from).step(15).each do |minutes|
            time = minutes.minutes.ago
            add_influx_point(
              name: Sensor::Config.measurement(:inverter_power_1),
              fields: {
                Sensor::Config.field(:inverter_power_1) => value1,
              },
              time:,
            )
            add_influx_point(
              name: Sensor::Config.measurement(:inverter_power_2),
              fields: {
                Sensor::Config.field(:inverter_power_2) => value2,
              },
              time:,
            )
          end
        end
      end

      it 'returns the per-bucket sum of its inputs, not an empty series' do
        seed_inverters(value1: 100.0, value2: 200.0, from: 180)

        data =
          series(
            sensors: ['inverter_power_total'],
            timeframe: 'P3H',
            resolution: '1h',
          )

        values = data[:series].first[:points].pluck(:value).compact
        expect(values).not_to be_empty
        expect(values).to all(eq(300.0)) # mean of constant (100 + 200)
      end

      it 'agrees with get_totals that the sensor has data' do
        seed_inverters(value1: 100.0, value2: 200.0, from: 180)

        series_sum =
          series(sensors: ['inverter_power_total'], timeframe: 'P3H', resolution: '1h')
            .dig(:series, 0, :points)
            .pluck(:value)
            .compact
            .sum
        totals =
          JSON.parse(
            McpServer::Tools::Totals.call(
              timeframe: 'P3H',
              sensors: ['inverter_power_total'],
            ).content.first[:text],
            symbolize_names: true,
          )

        expect(series_sum).to be > 0
        expect(totals[:totals].first[:value]).to be > 0
      end

      it 'returns null (not 0) for a bucket whose source data is missing' do
        # Only the most recent ~40 min carry data; earlier buckets are empty.
        seed_inverters(value1: 100.0, value2: 200.0, from: 40)

        data =
          series(
            sensors: ['inverter_power_total'],
            timeframe: 'P3H',
            resolution: '1h',
          )

        values = data[:series].first[:points].pluck(:value)
        expect(values).to include(nil)   # empty bucket -> null
        expect(values).to include(300.0) # bucket with data -> derived sum
      end
    end

    context 'with an absolute date range' do
      it 'accepts the range' do
        error, = call(
          sensors: ['battery_soc'],
          timeframe: '2024-01-01..2024-01-03',
          resolution: '1h',
        )

        expect(error).to be(false)
      end
    end

    context 'with the unsupported sum aggregation' do
      # get_series no longer offers "sum": a summed coarse series is not an
      # energy integration, so it is rejected for every sensor and the client
      # is pointed to get_totals for period totals.
      it 'rejects sum and points to get_totals' do
        error, text =
          call(
            sensors: ['inverter_power_forecast'],
            timeframe: 'P2D',
            resolution: '1h',
            aggregation: 'sum',
          )

        expect(error).to be(true)
        expect(text).to include('get_totals')
      end

      it 'rejects sum even on a non-power sensor' do
        error, = call(sensors: ['battery_soc'], timeframe: 'P2D', aggregation: 'sum')

        expect(error).to be(true)
      end

      it 'still allows mean/min/max' do
        %w[mean min max].each do |aggregation|
          error, =
            call(
              sensors: ['inverter_power_forecast'],
              timeframe: 'P2D',
              resolution: '1h',
              aggregation:,
            )

          expect(error).to be(false), "expected #{aggregation} to be allowed"
        end
      end
    end

    context 'with invalid input' do
      it 'rejects the now instant' do
        error, text = call(sensors: ['battery_soc'], timeframe: 'now')

        expect(error).to be(true)
        expect(text).to include('span')
      end

      it 'reports an unknown sensor' do
        error, text = call(sensors: ['nonexistent'], timeframe: 'P3H')

        expect(error).to be(true)
        expect(text).to include('Unknown or unconfigured')
      end

      it 'rejects too many sensors' do
        error, text = call(sensors: ['battery_soc'] * 21, timeframe: 'P3H')

        expect(error).to be(true)
        expect(text).to include('Too many sensors')
      end

      it 'reports an invalid timeframe' do
        error, text = call(sensors: ['battery_soc'], timeframe: 'not-a-timeframe')

        expect(error).to be(true)
        expect(text).to include('not a valid timeframe')
      end

      # The schema rejects these first; this is the backstop for a client
      # working from a cached schema, and "1d" WAS a valid label until
      # recently, so those clients exist. What it replaces is worse than an
      # error: an unknown label fell through to index 0 and answered the
      # COARSEST request with the FINEST bucket - 1440 points where 1 was
      # asked for, reported as `coarsened: true` with advice to shorten the
      # timeframe.
      it 'rejects a resolution outside the ladder, listing the ones that exist' do
        %w[1d 30m 1H].each do |bad|
          error, text = call(sensors: ['battery_soc'], timeframe: 'P3H', resolution: bad)

          expect(error).to be(true), "expected #{bad} to be rejected"
          expect(text).to include("Unknown resolution \"#{bad}\"", *described_class::Resolution::LABELS)
        end
      end

      # Two lists of the same thing drift, and this pair already did.
      it 'offers exactly the ladder it implements' do
        enum = described_class.input_schema.to_h.dig(:properties, :resolution, :enum)

        expect(enum).to eq(described_class::Resolution::LABELS)
      end

      it 'rejects sensors with no curve (money, chart-only composites)' do
        money_error, money_text = call(sensors: ['solar_price'], timeframe: 'P2D')
        expect(money_error).to be(true)
        expect(money_text).to include('get_totals')

        balance_error, = call(sensors: ['power_balance'], timeframe: 'P2D')
        expect(balance_error).to be(true)
      end

      # The rejection used to state every reason a sensor COULD have been
      # rejected for - four paragraphs, whichever sensor was asked for. The one
      # that did not apply was not merely noise: power_balance was sent to
      # get_totals, which rejects it as well (its `tools` is empty).
      describe 'the reason a sensor was rejected' do
        # A phrase per reason the message can carry, so an example can assert
        # that the other two are absent.
        let(:reasons) { ['accumulated', 'chart-only composite', 'Boolean and string'] }

        {
          'solar_price' => %w[accumulated get_totals],
          'power_balance' => ['chart-only composite'],
          'heatpump_status' => ['Boolean and string'],
        }.each do |sensor, expected|
          it "names only the one that applies to #{sensor}" do
            _error, text = call(sensors: [sensor], timeframe: 'P2D')

            expect(text).to include(sensor, *expected)
            (reasons - expected).each { expect(text).not_to include(_1) }
          end
        end

        # With several rejected sensors every reason is needed - but each one
        # carries the names it applies to, so the client does not have to guess
        # which is which.
        it 'pairs each reason with its sensors in a mixed request' do
          _error, text =
            call(sensors: %w[solar_price power_balance], timeframe: 'P2D')

          expect(text).to match(/solar_price: .*accumulated/)
          expect(text).to match(/power_balance: .*chart-only composite/)
        end
      end

      # InfluxDB refuses to fold a bool or string column into a bucket
      # ("unsupported aggregate column type bool"), and that error is no
      # ArgumentError, so it used to escape the tool as a bare internal error
      # - for a sensor list_sensors had advertised as series-capable.
      %w[wallbox_car_connected heatpump_status].each do |sensor|
        it "rejects the non-numeric #{sensor} with a usable message" do
          error, text = call(sensors: [sensor], timeframe: 'P2D')

          expect(error).to be(true)
          expect(text).to include('get_current_values', sensor)
        end
      end

      # One such sensor in the list took the whole response down with it, the
      # numeric sensors alongside it included.
      it 'rejects a mixed request rather than failing the whole query' do
        error, text = call(sensors: %w[house_power heatpump_status], timeframe: 'P2D')

        expect(error).to be(true)
        expect(text).to include('heatpump_status')
        expect(text).not_to include('house_power')
      end
    end
  end

  describe 'value normalization' do
    it 'collapses a signed negative zero to a plain 0.0' do
      result = McpServer::Tools::Series::Points.normalize_value(-0.0, :watt)

      # -0.0.to_json would serialise as "-0.0"; a normalized 0.0 must not.
      expect(result.to_json).to eq('0.0')
    end

    # Rounding a small negative value is a second way to produce a -0.0, so
    # the collapse has to happen after it, not before.
    it 'collapses a negative zero produced by rounding' do
      result = McpServer::Tools::Series::Points.normalize_value(-0.04, :watt)

      expect(result.to_json).to eq('0.0')
    end

    it 'leaves non-zero values and null untouched' do
      expect(McpServer::Tools::Series::Points.normalize_value(42.5, :watt)).to eq(42.5)
      expect(McpServer::Tools::Series::Points.normalize_value(nil, :watt)).to be_nil
    end

    it 'rounds by the unit policy' do
      expect(McpServer::Tools::Series::Points.normalize_value(42.55555, :percent)).to eq(42.6)
    end
  end
end
