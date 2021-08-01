class HomeController < ApplicationController
  include ParamsHandling

  def index
    unless timeframe && field
      redirect_to root_path(
                    timeframe: timeframe || 'now',
                    field: field || 'inverter_power',
                  )
    end
    raise ActionController::RoutingError, 'Not Found' if out_of_range?
  end

  private

  helper_method def nav_items
    [
      {
        name: t('calculator.now'),
        href: url_for(permitted_params.merge(timeframe: 'now', timestamp: nil)),
      },
      {
        name: t('calculator.day'),
        href:
          url_for(
            permitted_params.merge(
              timeframe: 'day',
              timestamp: corresponding_day,
            ),
          ),
      },
      {
        name: t('calculator.week'),
        href:
          url_for(
            permitted_params.merge(
              timeframe: 'week',
              timestamp: corresponding_week,
            ),
          ),
      },
      {
        name: t('calculator.month'),
        href:
          url_for(
            permitted_params.merge(
              timeframe: 'month',
              timestamp: corresponding_month,
            ),
          ),
      },
      {
        name: t('calculator.year'),
        href:
          url_for(
            permitted_params.merge(
              timeframe: 'year',
              timestamp: corresponding_year,
            ),
          ),
      },
      {
        name: t('calculator.all'),
        href: url_for(permitted_params.merge(timeframe: 'all', timestamp: nil)),
      },
    ]
  end
end
