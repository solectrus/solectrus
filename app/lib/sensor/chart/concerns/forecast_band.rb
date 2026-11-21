module Sensor
  module Chart
    module Concerns
      # The variability band around the PV forecast: the area between its lower
      # and its upper limit. It shows only after now, because the past shows
      # the actual generation.
      #
      # Prepended, so its style of the limits wins over the style of the chart.
      module ForecastBand
        BAND_SENSOR_NAMES = %i[
          inverter_power_forecast_min
          inverter_power_forecast_max
        ].freeze
        public_constant :BAND_SENSOR_NAMES

        private

        # The limits draw no line of their own, only the area between them,
        # faint behind the forecast. Its fill fades toward the foot of the
        # chart, but not to nothing, so the band stays visible where it is low
        # in the morning and the evening. Like the forecast line, they
        # need spanGaps true on a grid finer than the forecast. At night both
        # limits are zero, so a bridged night has no width.
        #
        # The lower limit comes first (#with_band), so Chart.js fills the band
        # from the upper limit down to the dataset 0. The tooltip shows the
        # band as one row at the upper limit, which reads the lower one from
        # the dataset that its `fill` names.
        def style_for_sensor(sensor)
          return super unless sensor.name.in?(BAND_SENSOR_NAMES)

          super.merge(
            borderWidth: 0,
            fillOpacity: 0.15,
            fillOpacityBottom: 0.04,
            # The faint fill vanishes on the dark background
            darkFillOpacity: 0.35,
            pointHoverRadius: 0,
            spanGaps: true,
            order: 1,
            **band_limit_style(sensor),
          )
        end

        def band_limit_style(sensor)
          if sensor.name == :inverter_power_forecast_max
            { fill: 0, label: I18n.t('forecast.range') }
          else
            { fill: false, tooltip: false }
          end
        end

        # The forecast as a line in front of the band, without a fill. Beyond
        # the horizon of the band, a fill would read as a band from zero up to
        # the forecast. The actual generation stays a filled area, so the two
        # differ without a hatch.
        #
        # The line is drawn in front of the actual generation as well, so the
        # past shows whether the generation was above or below the forecast.
        # It is dashed, while the actual generation is a solid area, so it
        # reads as a forecast. A darker (light theme) or lighter (dark theme)
        # tone keeps it visible on the area of the same color.
        def forecast_line_style
          Base::FORECAST_LINE_STYLE.merge(fill: false, hatchFill: false, order: -1)
        end

        def datasets(chart_data_items)
          sets = super
          labels = chart_data_items.first[:labels]
          actual = sets.find { |set| set[:id] == 'inverter_power' }
          cut = band_start(labels, actual&.dig(:data))
          sets = with_band(sets, labels, cut)

          forecast = sets.find { |set| set[:id] == 'inverter_power_forecast' }
          trim_night!(forecast[:data]) if forecast
          sets
        end

        # A single limit without the other is no band, so it does not show at
        # all. The limits come first: the fill of the upper limit names the
        # lower one by its index, and the tooltip lists the datasets from the
        # last to the first, so the band follows the forecast it surrounds.
        def with_band(sets, labels, cut)
          lower, upper = BAND_SENSOR_NAMES.map { |name| sets.find { |set| set[:id] == name.to_s } }
          others = sets - [lower, upper]
          return others unless lower && upper

          trim_band!(lower[:data], upper[:data], labels, cut)
          [lower, upper, *others]
        end

        # Removes the band before the index, where the actual generation shows.
        # It begins where the actual generation ends, so no gap opens between
        # the two (#band_start).
        #
        # Removes it also where it has no width: beyond its horizon (about 40
        # hours) and at night, both limits equal the forecast. A point next to
        # a band with width stays, so the band narrows to its end instead of
        # breaking off. Its limits are made equal, so the tooltip leaves it
        # out. An upper limit without a lower one has nothing to fill down to,
        # so it goes as well. Less than 1 W apart counts as no width.
        def trim_band!(lower, upper, labels, cut)
          interpolate_at!(cut, labels, lower, upper)
          lower.fill(nil, 0...cut)
          upper.fill(nil, 0...cut)
          upper.each_index { |index| upper[index] = nil if lower[index].nil? }

          points = (cut...upper.size).select { |index| upper[index] }
          flat = points.map { |index| (upper[index] - lower[index]).abs < 1 }
          remove_inner_points!(points, flat, lower, upper) { |index| upper[index] = lower[index] }
        end

        # The index of the last point of the actual generation, a few minutes
        # before now. Without an actual generation, the first point after now.
        def band_start(labels, actual)
          cut = future_cut_index(labels)
          last = actual&.rindex { |value| value }
          last && last < cut ? last : cut
        end

        # Gives the limits a value at the index, interpolated between the
        # points of the forecast on either side. So the band begins exactly
        # there, not at the next point of the coarser forecast.
        def interpolate_at!(index, labels, *arrays)
          arrays.each do |data|
            next if data[index]

            before = data[..index].rindex { |value| value }
            after = data.each_index.find { |i| i > index && data[i] }
            next unless before && after

            data[index] = linear_interpolate(labels, data, before, after, index)
          end
        end

        # Removes the forecast at night, where it is zero, so the tooltip shows
        # no forecast of 0 W all night. A zero next to the day stays, so the
        # curve still comes down to zero, and it is made exactly zero, so the
        # line hides the night (`hideZeroSegments`). Below 1 W counts as zero.
        def trim_night!(data)
          points = data.each_index.select { |index| data[index] }
          zero = points.map { |index| data[index].abs < 1 }
          remove_inner_points!(points, zero, data) { |index| data[index] = 0.0 }
        end

        # Removes each point of a run whose neighbours are in the run as well,
        # so the run keeps a point at each end, which the block gets. Only the
        # given points count: on a grid that is finer than the forecast, the
        # empty points between them belong to no run. Beyond either end of the
        # data counts as run.
        def remove_inner_points!(points, in_run, *arrays)
          [true, *in_run, true].each_cons(3).zip(points) do |window, index|
            if window.all?
              arrays.each { |data| data[index] = nil }
            elsif window[1]
              yield index
            end
          end
        end
      end
    end
  end
end
