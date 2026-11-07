# The comparison of the heat pump with a heating that burns oil or gas (see
# Heatpump::Comparison) on a page of its own, below the heat pump page, like
# the comparison of a car with a combustion car. The badge of the savings on
# the heat pump page leads to it in the same timeframe, and its way back
# leads there again. Like the heat pump page, it is open to everyone, and a
# sponsorship opens it. A phone opens it from the heat pump page in a sheet,
# like the comparison of a car (see SheetPage).
class Heatpump::SavingsController < ApplicationController
  include SheetPage
  include SummaryChecker

  before_action { head(:not_found) unless Sensor::HomePage.open?(:heatpump) }
  before_action { redirect_to(heatpump_home_path) unless Heatpump::Comparison.available? }

  # After the checks, so the timeframe select opens only with the page
  include TimeframeSelectModal
  include WholeTimeDefault

  # The live view and the last hours go to today. While days wait for the
  # build, the page shows the build instead of the comparison. Like the home
  # pages, it builds a few days at once.
  def index
    return redirect_to(heatpump_savings_path(timeframe: Timeframe.day.to_param)) unless Heatpump::Comparison.timeframe?(timeframe)

    load_missing_or_stale_summary_days(timeframe)
    @comparison = Heatpump::Comparison.new(timeframe)
  end

  # The prices of the fuel in a modal (see Car::FuelPriceChart), like
  # the fuel prices of the comparison of a car. The price range on the page
  # links to it, nothing without a price.
  def fuel_prices
    @comparison = Heatpump::Comparison.new(timeframe)
    head(:not_found) unless Heatpump::Comparison.timeframe?(timeframe) && @comparison.fuel_series.any?
  end

  private

  helper_method def timeframe_page
    TimeframePage::List.new(route: :heatpump_savings_path, params: {}, kinds: Heatpump::Comparison::TIMEFRAME_KINDS)
  end

  # The heat pump page in the timeframe of the comparison
  helper_method def back_path = heatpump_home_path(sensor_name: 'heatpump_heating_power', timeframe: timeframe.to_param)

  helper_method def title
    heating = @comparison.heating
    heating.configured? ? t('heatpump_comparison.title', heating: heating.name) : t('heatpump_comparison.title_none')
  end
end
