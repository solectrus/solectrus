class HomeController < ApplicationController
  include ParamsHandling

  def index
    redirect_to root_path(field: 'inverter_power') unless field

    raise ActionController::RoutingError, 'Not Found' if timeframe.out_of_range?
  end

  private

  helper_method def nav_items
    [
      {
        name: t('calculator.now'),
        href: url_for(permitted_params.merge(timeframe: 'now')),
      },
      {
        name: t('calculator.day'),
        href:
          url_for(
            permitted_params.merge(timeframe: timeframe.corresponding_day),
          ),
      },
      {
        name: t('calculator.week'),
        href:
          url_for(
            permitted_params.merge(timeframe: timeframe.corresponding_week),
          ),
      },
      {
        name: t('calculator.month'),
        href:
          url_for(
            permitted_params.merge(timeframe: timeframe.corresponding_month),
          ),
      },
      {
        name: t('calculator.year'),
        href:
          url_for(
            permitted_params.merge(timeframe: timeframe.corresponding_year),
          ),
      },
      {
        name: t('calculator.all'),
        href: url_for(permitted_params.merge(timeframe: 'all')),
      },
    ]
  end
end
