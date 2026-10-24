# The timeframe of a phone: one row of three segments in the header (see
# Timeframe::Segments::Component), and the comparisons of the years in its
# timeframe select. A part of TimeframeNavigation, whose addresses it uses.
module TimeframeSegments
  extend ActiveSupport::Concern

  included do
    private

    # The timeframe of a phone in one row (see TimeframeSegmentItems). The
    # period names the one of the page, or the current one of the kind chosen
    # last (see #remembered_period). Once it is the current one, it opens the
    # timeframe select in the sheet instead, as a tab of the wide screen opens
    # its menu.
    helper_method def segment_items
      TimeframeSegmentItems.new(
        timeframe:,
        period: timeframe.period? ? timeframe : remembered_period || Timeframe.year,
        path: ->(timeframe) { path_with_timeframe(timeframe) },
        live: live_item,
        forecast_path: (forecast_path if TimeframePage::Sensor.new(namespace: helpers.controller_namespace, sensor_name: nil).forecast?),
        period_item: comparison_segment,
      ).to_h
    end

    # A comparison of the years leaves the cut of the year to the axis of its
    # chart, and keeps the comparison in its address
    def comparison_segment
      return {} unless timeframe.period? && year_comparison?

      { name: t('data.year_comparison'), href: path_with_timeframe(timeframe.to_param, compare: year_comparison) }
    end

    # The period that holds today, of the kind the home page saw last (see
    # HomePageController#remember_timeframe)
    def remembered_period
      last = Timeframe.new(session[:period_timeframe].to_s)
      current_of_kind(last) if period_kind?(last)
    rescue ArgumentError
      nil
    end

    # A window counted back from now, like the last 90 days, is no kind of
    # period: the arrows do not turn it. The whole time is one, also in months.
    def period_kind?(timeframe) = timeframe.period? && (!timeframe.relative? || timeframe.all_like?)

    # The current week, month or year. The whole time stays as it is. A day or
    # a range has no such period of its own, so it gives the current month.
    def current_of_kind(period)
      return period if period.all_like?

      Timeframe.new(period.week? || period.year? ? period.id.to_s : 'month')
    end

    # The comparisons of the years, which the timeframe select of a phone
    # offers below its fields, as the menu of the tab of a wide screen does
    # (see Timeframe::Select::LinkGroup::Component). A page that cannot
    # compare its sensor has none.
    helper_method def year_comparison_items
      return [] unless Sensor::Chart::YearComparison.available_for?(sensor)

      Sensor::Chart::YearComparison.variants.map do |variant|
        { name: t(variant::SHORT_LABEL_KEY), href: path_with_timeframe('all', compare: variant::PARAM), current: year_comparison == variant::PARAM }
      end
    end
  end
end
