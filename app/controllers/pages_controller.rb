class PagesController < ApplicationController
  def about
    set_meta_tags title: 'Über Solectrus',
                  description:
                    'Solectrus ist ein alternatives Photovoltaik-Dashboard, das Ertrag und Verbrauch einer PV-Anlage visualisiert.',
                  og: {
                    title: :title,
                    description: :description,
                    site_name: :site,
                    url: about_url,
                    type: 'website',
                    image: '/og-image.png',
                  }
  end
end
