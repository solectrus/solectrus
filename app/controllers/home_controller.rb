class HomeController < ApplicationController
  include ParamsHandling

  def index
    unless field
      redirect_to root_path(field: 'inverter_power', timeframe: 'now')
    end

    raise ActionController::RoutingError, 'Not Found' if timeframe.out_of_range?
    set_meta_tags title: helpers.title,
                  description: 'Solarstrom aus der Photovoltaik-Anlage',
                  keywords: 'photovoltaik, strom, solar, energiewende',
                  noindex: timeframe?,
                  og: {
                    title: :title,
                    description: :description,
                    site_name: :site,
                    url: request.url,
                    type: 'website',
                    image: '/og-image.png',
                  }
  end

  private

  helper_method def nav_items
    [
      {
        name: t('calculator.now'),
        href: path_with_timeframe('now'),
        rel: 'nofollow',
      },
      {
        name: t('calculator.day'),
        href: path_with_timeframe(timeframe.corresponding_day),
        rel: 'nofollow',
      },
      {
        name: t('calculator.week'),
        href: path_with_timeframe(timeframe.corresponding_week),
        rel: 'nofollow',
      },
      {
        name: t('calculator.month'),
        href: path_with_timeframe(timeframe.corresponding_month),
        rel: 'nofollow',
      },
      {
        name: t('calculator.year'),
        href: path_with_timeframe(timeframe.corresponding_year),
        rel: 'nofollow',
      },
      {
        name: t('calculator.all'),
        href: path_with_timeframe('all'),
        rel: 'nofollow',
      },
    ]
  end

  def path_with_timeframe(timeframe)
    url_for(permitted_params.merge(timeframe:, only_path: true))
  end
end
