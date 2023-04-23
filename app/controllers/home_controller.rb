class HomeController < ApplicationController
  include ParamsHandling

  def index
    unless field
      redirect_to root_path(field: 'inverter_power', timeframe: 'now')
    end

    set_meta_tags title: helpers.title,
                  description:
                    'Alternatives Dashboard zur übersichtlichen Darstellung und Analyse von Messwerten einer Photovoltaik-Anlage zur optimierten Leistungskontrolle',
                  keywords: 'photovoltaik, strom, solar, energiewende',
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

  def path_with_timeframe(timeframe)
    url_for(permitted_params.merge(timeframe:, only_path: true))
  end

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
end
