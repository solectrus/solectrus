class HomeController < ApplicationController
  include ParamsHandling

  def index
    unless field
      redirect_to root_path(field: 'inverter_power', timeframe: 'now')
    end

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
      { name: t('calculator.now'), href: path_with_timeframe('now') },
      {
        name: t('calculator.day'),
        href: path_with_timeframe(timeframe.corresponding_day),
      },
      {
        name: t('calculator.week'),
        href: path_with_timeframe(timeframe.corresponding_week),
      },
      {
        name: t('calculator.month'),
        href: path_with_timeframe(timeframe.corresponding_month),
      },
      {
        name: t('calculator.year'),
        href: path_with_timeframe(timeframe.corresponding_year),
      },
      { name: t('calculator.all'), href: path_with_timeframe('all') },
    ]
  end

  helper_method def refresh_options
    return unless timeframe.current?

    {
      controller: 'refresh',
      'refresh-field-value': field,
      'refresh-interval-value': (timeframe.now? ? 5.seconds : 5.minutes),
      'refresh-reload-chart-value': !timeframe.now?,
      'refresh-next-path-value':
        root_path(field:, timeframe: timeframe.next(force: true)),
      'refresh-boundary-value':
        timeframe.next_date(force: true)&.to_time&.iso8601,
    }
  end

  def path_with_timeframe(timeframe)
    url_for(permitted_params.merge(timeframe:, only_path: true))
  end
end
