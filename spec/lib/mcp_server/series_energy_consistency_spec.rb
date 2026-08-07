# KNOWN LIMIT, pinned rather than fixed: a get_series curve and the energy the
# summaries hold are two readings of the same measurements, but they do not
# integrate to the same number for a sensor written on CHANGE rather than on a
# clock.
#
# The summaries integrate over time (Influx::Integral, `integral(unit: 1h)`),
# while a series bucket is `aggregateWindow(fn: mean)` - the mean of the
# SAMPLES in the bucket. A duty-cycling consumer writes densely while it draws
# power and not at all while it idles, so the idle stretches never enter the
# denominator, and the wider the bucket the more of them it swallows. On
# demo.solectrus.de a fridge reads 53.9 W at "1d" (1,294 Wh for the day) where
# get_totals says 415 Wh.
#
# This spec exists so the size and the DIRECTION of that gap are written down
# and cannot drift unnoticed: the get_series description tells clients a coarse
# bucket drifts from the summaries, and these are the numbers behind that
# sentence. Fixing it means making the bucket mean time-weighted, which changes
# what a null bucket means for every sparse sensor and reaches the web UI's
# chart queries - deliberately not done here.
#
# The tables below drive Sensor::Query::Series directly, so they cover "1d" as
# well, which the web UI charts request. get_series itself stops at "1h" and at
# Series::MAX_SPAN, which is what keeps a client from meeting the widest gap
# here through the tool: the wider the bucket, the further the mean drifts.
#
# The subject is the relationship between get_series and get_totals, not one
# class.
describe 'get_series energy consistency' do # rubocop:disable RSpec/DescribeClass
  # A day of a fridge compressor: 10 minutes on at 55 W, 20 minutes off,
  # written only when it switches. Its true energy is a third of 55 W over 24
  # hours.
  def duty_cycle = 30.minutes
  def on_phase = 10.minutes
  def on_watts = 55.0

  # A base load written on a clock, every minute, so the house curve stays
  # dense whatever the fridge does. This is the sensor that behaves.
  def base_watts = 80.0

  let(:date) { Date.new(2024, 6, 12) }
  let(:timeframe) { Timeframe.new(date.iso8601) }
  let(:beginning) { timeframe.beginning }

  let(:expected_fridge_wh) { on_watts * 24 * on_phase.to_i / duty_cycle.to_f }
  let(:expected_base_wh) { base_watts * 24 }

  before do
    influx_batch do
      # The fridge, written only when it changes: the old value one second
      # before each switch and the new one at it, so the edges are steps rather
      # than the ramps a lone point per switch would integrate to. Between them
      # it writes nothing at all - which is what leaves whole buckets empty and
      # the idle minutes out of any mean over the samples.
      (1.day.to_i / duty_cycle.to_i).times do |cycle|
        start = beginning + (cycle * duty_cycle)

        {
          (start - 1) => 0.0,
          start => on_watts,
          (start + on_phase - 1) => on_watts,
          (start + on_phase) => 0.0,
        }.each do |time, watts|
          add_influx_point(
            name: Sensor::Config.measurement(:custom_power_02),
            fields: { Sensor::Config.field(:custom_power_02) => watts },
            time:,
          )
        end
      end

      # The base load, and the house meter that sees both.
      (1.day.to_i / 60).times do |minute|
        time = beginning + (minute * 60)
        fridge_on = (time - beginning).to_i % duty_cycle.to_i < on_phase.to_i

        add_influx_point(
          name: Sensor::Config.measurement(:custom_power_01),
          fields: { Sensor::Config.field(:custom_power_01) => base_watts },
          time:,
        )
        add_influx_point(
          name: Sensor::Config.measurement(:house_power),
          fields: {
            Sensor::Config.field(:house_power) =>
              (fridge_on ? on_watts : 0.0) + base_watts,
          },
          time:,
        )
      end
    end
  end

  def series(sensor_names, interval)
    Sensor::Query::Series.new(
      sensor_names,
      timeframe,
      interval: interval.seconds,
      aggregation: :avg,
      timestamp_method: :to_time,
    ).call
  end

  # The curve integrated over the day, in Wh: every bucket's mean power counts
  # for the hours the bucket covers.
  def integrated_wh(data, sensor_name, interval)
    buckets = data.public_send(sensor_name, :avg, :avg) || {}

    buckets.values.compact.sum * interval / 3600.0
  end

  # What the summaries store for that day - the time-weighted integral every
  # total on this instance is built from, and the number to measure against.
  def summary_wh(sensor_name)
    Sensor::Query::Helpers::Influx::Integral.new([sensor_name], timeframe)
      .call
      .public_send(sensor_name)
  end

  describe 'the authoritative energy' do
    it 'integrates the fridge to a third of its on-power' do
      expect(summary_wh(:custom_power_02)).to be_within(20).of(expected_fridge_wh)
    end

    it 'integrates the base load to its flat power' do
      expect(summary_wh(:custom_power_01)).to be_within(5).of(expected_base_wh)
    end
  end

  # A sensor written on a clock integrates back to its energy at every
  # resolution. Nothing about bucketing is broken - only about which samples a
  # bucket happens to hold.
  { '1m' => 60, '5m' => 300, '15m' => 900, '1h' => 3600, '1d' => 86_400 }.each do |label, interval|
    it "integrates a clock-written sensor to its daily energy at #{label}" do
      curve = integrated_wh(series([:custom_power_01], interval), :custom_power_01, interval)

      expect(curve).to be_within(expected_base_wh * 0.1).of(expected_base_wh)
    end
  end

  # The on-change sensor, resolution by resolution. Too LOW where the idle
  # stretches are holes the mean skips over, too HIGH once a bucket is wide
  # enough to hold both phases and count only the samples.
  {
    '1m' => [60, 88.0],
    '5m' => [300, 440.0],
    '15m' => [900, 440.0],
    '1h' => [3600, 663.9],
    '1d' => [86_400, 662.4],
  }.each do |label, (interval, expected)|
    it "reads #{expected} Wh at #{label}, where the true energy is 440.0 Wh" do
      curve = integrated_wh(series([:custom_power_02], interval), :custom_power_02, interval)

      expect(curve).to be_within(2.0).of(expected)
    end
  end

  # What the split does with that. custom_power_total sums its members per
  # bucket, and house_power_without_custom is house_power minus that sum, so
  # the fridge's overstatement lands in the "other consumers" share - the
  # resolution-dependent split reported against demo.solectrus.de.
  describe 'the house/custom split' do
    def split(interval)
      data =
        series(%i[house_power custom_power_total house_power_without_custom], interval)

      house = data.house_power(:avg, :avg)
      custom = data.custom_power_total
      rest = data.house_power_without_custom

      house.filter_map do |time, value|
        next if value.nil?

        [value, custom[time].to_f, rest[time].to_f]
      end
    end

    # Below an hour the parts still sum to the whole.
    { '1m' => 60, '5m' => 300, '15m' => 900 }.each do |label, interval|
      it "keeps custom + without_custom equal to house_power at #{label}" do
        mismatches =
          split(interval).filter_map do |house, custom, rest|
            "house=#{house} parts=#{custom + rest}" if (custom + rest - house).abs > 0.15
          end

        expect(mismatches).to be_empty, "parts do not sum to the whole:\n#{mismatches.join("\n")}"
      end
    end

    # From an hour up it stops adding up, and not only because custom is too
    # high: house_power_without_custom floors at 0 (see its `calculate` block),
    # so once the overstated custom share exceeds house_power the difference is
    # clamped away instead of going negative. The identity then fails silently,
    # and the missing energy is invisible rather than obviously wrong.
    { '1h' => 3600, '1d' => 86_400 }.each do |label, interval|
      it "loses the identity to the 0-floor at #{label}" do
        rows = split(interval)

        expect(rows).to all(satisfy { |house, custom, _rest| custom > house })
        expect(rows).to all(satisfy { |_house, _custom, rest| rest.zero? })
      end
    end
  end
end
