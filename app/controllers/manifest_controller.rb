# Serves the web app manifest. This is a route, not a static file in public/,
# so the theme colors come from ThemeConfig instead of a second hand-kept copy.
#
# Inherits from ActionController::Base, because the manifest must stay
# reachable when a lockup codeword or the browser check blocks the app.
class ManifestController < ActionController::Base
  include AutoLocale

  def show
    # Private, because the answer carries the locale of this visitor. A shared
    # cache would hand the language of one visitor to the next. Vary makes a
    # browser fetch again when the Accept-Language header changes. The locale
    # cookie beats that header, but a cookie change stays inside one browser,
    # where the private cache belongs to that visitor anyway.
    expires_in 1.hour
    response.headers['Vary'] = 'Accept-Language'

    render json: manifest, content_type: 'application/manifest+json'
  end

  private

  def manifest
    {
      id: 'solectrus',
      name: 'SOLECTRUS',
      short_name: 'SOLECTRUS',
      description: t('manifest.description'),
      lang: I18n.locale,
      scope: '/',
      start_url: '/',
      # No visitor here, the manifest is one answer for the whole install. So
      # this is the light color, unless UI_THEME fixes the theme to dark.
      background_color: ThemeConfig.x.color,
      theme_color: ThemeConfig.x.color,
      display: 'standalone',
      orientation: 'portrait',
      author: 'Georg Ledermann',
      developer: {
        name: 'Georg Ledermann',
        url: 'https://ledermann.dev',
      },
      icons:,
    }
  end

  def icons
    %w[192 512].product(%w[any maskable]).map do |size, purpose|
      {
        src: "/manifest-icon-#{size}.maskable.png",
        sizes: "#{size}x#{size}",
        type: 'image/png',
        purpose:,
      }
    end
  end
end
