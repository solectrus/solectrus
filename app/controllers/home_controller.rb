class HomeController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    unless field && timeframe
      redirect_to root_path(field: field || redirect_field, timeframe: 'now')
      return
    end

    set_meta_tags title:,
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

  # By default we want to show the current production, so we redirect to the inverter_power field.
  # But at night this does not make sense, so in this case we redirect to the house_power field.
  def redirect_field
    DayLight.active? ? 'inverter_power' : 'house_power'
  end
end
