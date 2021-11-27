class HomeController < ApplicationController
  include ParamsHandling

  def index
    unless period && field
      redirect_to root_path(
                    period: period || 'now',
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
        href: url_for(permitted_params.merge(period: 'now', timestamp: nil)),
      },
      {
        name: t('calculator.day'),
        href:
          url_for(
            permitted_params.merge(period: 'day', timestamp: corresponding_day),
          ),
      },
      {
        name: t('calculator.week'),
        href:
          url_for(
            permitted_params.merge(
              period: 'week',
              timestamp: corresponding_week,
            ),
          ),
      },
      {
        name: t('calculator.month'),
        href:
          url_for(
            permitted_params.merge(
              period: 'month',
              timestamp: corresponding_month,
            ),
          ),
      },
      {
        name: t('calculator.year'),
        href:
          url_for(
            permitted_params.merge(
              period: 'year',
              timestamp: corresponding_year,
            ),
          ),
      },
      {
        name: t('calculator.all'),
        href: url_for(permitted_params.merge(period: 'all', timestamp: nil)),
      },
    ]
  end
end
