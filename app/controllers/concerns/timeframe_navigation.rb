module TimeframeNavigation
  extend ActiveSupport::Concern

  included do
    private

    helper_method def title
      timeframe.localized
    end

    # `compare` is named even when there is nothing to compare, so that a tab
    # leading away from the year comparison does not carry it along: `url_for`
    # would otherwise take the segment from the path of the current page.
    def path_with_timeframe(timeframe, compare: nil)
      url_for(
        controller: "#{helpers.controller_namespace}/home",
        sensor_name:,
        timeframe:,
        compare:,
        action: 'index',
        **selection_params,
      )
    end

    helper_method def nav_items
      [
        {
          name: t('data.now'),
          href: path_with_timeframe('now'),
          current: timeframe.now?,
        },
        nav_item(:day),
        nav_item(:week),
        nav_item(:month),
        nav_item(:year),
        nav_item(:all),
      ]
    end

    # One tab, named after its period. It leads to the next reading of that
    # period, which is what it has always done, and carries every reading as a
    # menu once it is the current one -- the others lead somewhere first.
    def nav_item(period)
      current = timeframe.public_send(:"#{period}_like?")

      {
        name: t("data.#{period}"),
        href: path_with_timeframe(corresponding(timeframe, period).to_s),
        current:,
        menu: (menu_items_for(period) if current),
      }
    end

    # The readings of the period a tab stands for: this month or the last 30
    # days, this year or the last 12 months or the last 365 days, the whole
    # record or the rolling window of its length. Each one used to be reached
    # by clicking the tab again, and nothing announced that.
    #
    # A period of the past has a single reading and gets no menu.
    def menu_items_for(period)
      entries = readings(period).map { |reading| reading_entry(reading, period) }
      entries = with_year_comparison(entries) if period == :all

      entries unless entries.one?
    end

    # A page standing on a period of the past puts that period first, so the
    # menu says where it stands before it offers the ways on. The readings
    # below it are always the ones that are running: a month that is over has
    # no "last 30 days" of its own.
    def readings(period)
      here = corresponding(timeframe, period)
      running = running_readings(period)
      return running if running.any? { |reading| reading.to_s == here.to_s }

      [here, *running]
    end

    # The cycle the tab has always walked, followed to its end, so the menu can
    # offer nothing the clicks did not. It is turned to begin at the calendar
    # reading, so the menu reads the same however it was reached.
    def running_readings(period)
      cycle = []
      reading = corresponding(Timeframe.new('now'), period)

      until cycle.any? { |entry| entry.to_s == reading.to_s }
        cycle << reading
        reading = corresponding(reading, period)
      end

      cycle.rotate(cycle.index { |entry| !entry.relative? } || 0)
    end

    def corresponding(reading, period)
      Timeframe.new(reading.public_send(:"corresponding_#{period}"))
    end

    def reading_entry(reading, period)
      {
        name: reading_name(reading, period),
        href: path_with_timeframe(reading.to_s),
        current: reading.to_s == timeframe.to_s,
      }
    end

    # The period that is running is named by what it is: "this month" says
    # plainly where the entry leads, while "September 2026" leaves the reader
    # to work out that this is the month we are in. A period that is over has
    # only its date to go by.
    def reading_name(reading, period)
      return all_reading_name(reading) if period == :all
      return reading.localized if reading.relative? || !reading.current?

      t("timeframe.#{reading.id}")
    end

    # The readings of the whole record run from the same day to the same day,
    # and differ in the bars they draw. So they are named after those rather
    # than after a span, which would name them both the same.
    #
    # The rolling window is as many months as there are, up to the 99 a
    # timeframe can name. Beyond that "all months" is a month or two short.
    def all_reading_name(reading)
      reading.relative? ? t('data.all_months') : t('data.all_years')
    end

    # The chart of the whole record can be read another way: the same month
    # of every year side by side. That says how the chart is drawn, not which
    # period it covers, so its entry is named after the comparison it offers
    # rather than after a span, and it stands below the spans and behind a
    # line.
    #
    # The whole record is the period it draws, so its entry is the one that
    # leads back out of a comparison.
    def with_year_comparison(entries)
      return entries unless Sensor::Chart::YearComparison.available_for?(sensor)

      whole, *rest = entries

      [
        whole.merge(current: whole[:current] && !year_comparison?),
        *rest,
        *Sensor::Chart::YearComparison.variants.each_with_index.map do |variant, index|
          comparison_entry(variant, separator_before: index.zero?)
        end,
      ]
    end

    def comparison_entry(variant, separator_before:)
      {
        name: t(variant::LABEL_KEY),
        href: path_with_timeframe('all', compare: variant::PARAM),
        current: year_comparison == variant::PARAM,
        separator_before:,
      }
    end
  end
end
