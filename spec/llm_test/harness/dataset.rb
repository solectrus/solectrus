module LlmTest
  # The fixture instance the tests run against.
  #
  # Everything here is deterministic: the same clock, the same curves, the same
  # summaries on every run. That is what makes an answer checkable at all - the
  # expected numbers are not typed into the cases, they are computed here from
  # the very curves the fixture was built from (see FACTS).
  #
  # One generator feeds both stores, so InfluxDB and the PostgreSQL summaries
  # can never disagree: get_series (InfluxDB) and get_totals (summaries) answer
  # the same day with the same energy.
  module Dataset # rubocop:disable Metrics/ModuleLength
    module_function

    # The clock every test runs under: the real time, frozen at the start of
    # the run. The running day is therefore partly measured and yesterday is a
    # full day.
    #
    # It has to be the REAL time, for two reasons. Claude Code tells the model
    # what day it is and we cannot stop it, so a fixture in the past makes the
    # model ask for a timeframe wide of the data. And InfluxDB answers "what is
    # the current value" from its own wall clock, so a measurement written for
    # a later hour lies in its future and no live reading finds it.
    def now = @now ||= Time.zone.now.change(sec: 0) # rubocop:disable ThreadSafety/ClassInstanceVariable

    def today = now.to_date
    def yesterday = today - 1

    # The first day with a summary: the start of the month before last. That
    # gives one completed month to rank days in, and the running month to
    # compare it against.
    def first_day = (today << 2).beginning_of_month

    def last_month = (today << 1).beginning_of_month

    # One measurement per minute, which is the resolution get_series works at:
    # coarser fixture data would leave the intraday curve full of gaps that no
    # real installation has.
    STEP = 1.minute
    POINTS_PER_DAY = 24 * 60
    public_constant :STEP, :POINTS_PER_DAY

    # The sensors the fixture carries data for. Everything else this instance
    # has configured stays empty on purpose - a test must also see what a
    # sensor without data looks like.
    SUMMARY_SENSORS = %i[
      inverter_power
      house_power
      heatpump_power
      custom_power_01
      grid_import_power
      grid_export_power
    ].freeze
    public_constant :SUMMARY_SENSORS

    # The operator named this consumer themselves, so the user says
    # "Waschmaschine" and never "custom_power_01". Resolving that is what
    # list_sensors' `query` filter exists for.
    SENSOR_NAMES = { custom_power_01: 'Waschmaschine' }.freeze
    public_constant :SENSOR_NAMES

    # Where a fixture sensor is written in InfluxDB. inverter_power is not
    # measured in this configuration - it is the sum of the two single
    # inverters, so the curve is split between them.
    def influx_targets
      {
        inverter_power_1: [Sensor::Config.measurement(:inverter_power_1), Sensor::Config.field(:inverter_power_1)],
        inverter_power_2: [Sensor::Config.measurement(:inverter_power_2), Sensor::Config.field(:inverter_power_2)],
        house_power: [Sensor::Config.measurement(:house_power), Sensor::Config.field(:house_power)],
        heatpump_power: [Sensor::Config.measurement(:heatpump_power), Sensor::Config.field(:heatpump_power)],
        custom_power_01: [Sensor::Config.measurement(:custom_power_01), Sensor::Config.field(:custom_power_01)],
        grid_import_power: [Sensor::Config.measurement(:grid_import_power), Sensor::Config.field(:grid_import_power)],
        grid_export_power: [Sensor::Config.measurement(:grid_export_power), Sensor::Config.field(:grid_export_power)],
      }
    end

    ### The generator ###########################################################

    # How sunny a day is, from 0.15 to 0.95. A fixed function of the day of the
    # year, so it is stable across runs but varied enough that no two days in a
    # month share a rank.
    def weather(date)
      (Math.sin(date.yday * 1.7) * 0.4) + 0.55
    end

    # Power in watts of one sensor at point `i` of `date`.
    def power(sensor, date, index)
      hour = index * 24.0 / POINTS_PER_DAY

      case sensor
      when :inverter_power then pv_power(date, hour)
      when :house_power then house_power(hour)
      when :heatpump_power then heatpump_power(date, hour)
      when :custom_power_01 then washer_power(hour)
      when :grid_import_power then [demand(date, hour) - pv_power(date, hour), 0].max
      when :grid_export_power then [pv_power(date, hour) - demand(date, hour), 0].max
      else raise ArgumentError, "no curve for #{sensor}"
      end
    end

    # A bell over the daylight hours, scaled by the day's weather.
    def pv_power(date, hour)
      return 0.0 if hour < 5 || hour > 21

      shape = Math.sin((hour - 5) * Math::PI / 16)**1.6
      (weather(date) * 9000 * shape).round(1)
    end

    def house_power(hour)
      base = 350.0
      base += 800 if hour >= 7 && hour < 9
      base += 1200 if hour >= 18 && hour < 21
      base
    end

    # Heating in the cold half of the year, hot water alone in the warm one.
    def heatpump_power(date, hour)
      return 0.0 if hour < 11 || hour >= 15

      date.month.between?(4, 9) ? 400.0 : 1800.0
    end

    # Runs once a day, mid-morning. Every day, so a question about yesterday
    # always has an answer.
    def washer_power(hour)
      hour >= 10 && hour < 11.5 ? 1500.0 : 0.0
    end

    def demand(date, hour)
      house_power(hour) + heatpump_power(date, hour)
    end

    def curve(sensor, date)
      (0...POINTS_PER_DAY).map { |i| power(sensor, date, i) }
    end

    # Energy of a full day in Wh. The curve is a power sampled at even steps,
    # so its mean times 24 hours is the energy - which is exactly what the
    # summaries store for a watt sensor.
    def energy_wh(sensor, date)
      (curve(sensor, date).sum / POINTS_PER_DAY * 24).round(1)
    end

    ### Seeding #################################################################

    def seed!
      Setting.sensor_names = SENSOR_NAMES.stringify_keys
      seed_summaries!
      seed_influx!
    end

    def seed_summaries!
      Summary.reset!

      dates = (first_day..yesterday).to_a
      Summary.insert_all!(
        dates.map { { date: _1, created_at: now, updated_at: now } },
      )
      SummaryValue.insert_all!(dates.flat_map { summary_values(_1) })
    end

    # One row per stored aggregation, all derived from the same curve.
    def summary_values(date)
      SUMMARY_SENSORS.flat_map do |sensor|
        points = curve(sensor, date)

        Sensor::Registry[sensor].summary_aggregations.map do |aggregation|
          value =
            case aggregation
            when :sum then energy_wh(sensor, date)
            when :max then points.max
            when :min then points.min
            when :avg then (points.sum / points.size).round(1)
            end

          { date:, field: sensor, aggregation:, value: }
        end
      end
    end

    # Raw measurements for the two days a live reading or an intraday curve can
    # ask about: yesterday in full, today up to the frozen clock.
    def seed_influx!
      InfluxHelper.delete_all!

      points = influx_points(yesterday) + influx_points(today)
      points.each_slice(2_000) { InfluxHelper.write!(_1) }
    end

    def influx_points(date)
      last = date == today ? ((now - date.beginning_of_day) / STEP).to_i : POINTS_PER_DAY

      (0...last).map do |i|
        time = date.beginning_of_day + (i * STEP)

        influx_fields(date, i).map do |measurement, fields|
          { name: measurement, time: time.to_i, fields: }
        end
      end.flatten
    end

    # Several sensors share a measurement, so their fields go into ONE point per
    # measurement and timestamp - as a collector would write them.
    def influx_fields(date, index)
      pv = power(:inverter_power, date, index)

      values = {
        inverter_power_1: (pv * 0.9).round(1),
        inverter_power_2: (pv * 0.1).round(1),
        # The house meter measures the heat pump too; SOLECTRUS subtracts it
        # again (INFLUX_EXCLUDE_FROM_HOUSE_POWER), so what is written here has
        # to be the meter's total for the live reading to match the summaries.
        house_power: power(:house_power, date, index) + power(:heatpump_power, date, index),
        heatpump_power: power(:heatpump_power, date, index),
        custom_power_01: power(:custom_power_01, date, index),
        grid_import_power: power(:grid_import_power, date, index),
        grid_export_power: power(:grid_export_power, date, index),
      }

      targets = influx_targets

      values.each_with_object(Hash.new { |h, k| h[k] = {} }) do |(sensor, value), result|
        measurement, field = targets[sensor]
        result[measurement][field] = value.to_f
      end
    end

    ### Ground truth ############################################################

    # The numbers a case may assert on, computed from the same curves the
    # fixture was built from. A case names a fact; it never repeats a number.
    def facts
      days = (last_month..last_month.end_of_month).to_a
      best = days.max_by { energy_wh(:inverter_power, _1) }

      {
        'pv_yesterday_kwh' => energy_wh(:inverter_power, yesterday) / 1000.0,
        'house_yesterday_kwh' => energy_wh(:house_power, yesterday) / 1000.0,
        'washer_yesterday_kwh' => energy_wh(:custom_power_01, yesterday) / 1000.0,
        'grid_import_yesterday_kwh' => energy_wh(:grid_import_power, yesterday) / 1000.0,
        'pv_last_month_kwh' => days.sum { energy_wh(:inverter_power, _1) } / 1000.0,
        'best_day_last_month_kwh' => energy_wh(:inverter_power, best) / 1000.0,
        'best_day_last_month_day' => best.day.to_f,
        'pv_now_watt' => power(:inverter_power, today, ((now - today.beginning_of_day) / STEP).to_i - 1),
      }
    end
  end

  # Writing to InfluxDB without the RSpec helper, which is bound to the suite.
  module InfluxHelper
    module_function

    def write!(points)
      Influx.client.create_write_api.write(
        data: points,
        bucket: Rails.configuration.x.influx.bucket,
        org: Rails.configuration.x.influx.org,
      )
    end

    def delete_all!
      Influx
        .client
        .create_delete_api
        .delete(Time.zone.at(0), Time.zone.at((2**63) / 1_000_000_000))
    end
  end
end
