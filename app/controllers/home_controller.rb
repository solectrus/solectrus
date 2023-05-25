class HomeController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    unless field && timeframe
      redirect_to root_path(field: field || 'inverter_power', timeframe: 'now')
      return
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
end
