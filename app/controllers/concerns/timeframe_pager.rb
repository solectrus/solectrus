# The period of a phone at the top of the content (see
# Timeframe::Pager::Component), and the comparisons of the years in its
# timeframe select. A part of TimeframeNavigation, whose addresses it uses.
module TimeframePager
  extend ActiveSupport::Concern

  included do
    private

    # A comparison of the years has no period to turn, and the menu of its tab
    # picks the comparison, so it shows no period, as the live view
    helper_method def pager_items
      items = TimeframePagerItems.new(
        timeframe:,
        path: ->(timeframe) { path_with_timeframe(timeframe) },
        forecast_path: (forecast_path if TimeframePage::Sensor.new(namespace: helpers.controller_namespace, sensor_name: nil).forecast?),
      ).to_h
      year_comparison? ? items.merge(period: nil) : items
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
