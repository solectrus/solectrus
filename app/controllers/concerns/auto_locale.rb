module AutoLocale
  extend ActiveSupport::Concern

  included do
    around_action :switch_locale

    private

    def switch_locale(&)
      I18n.with_locale(requested_locale, &)
    end

    # User-chosen locale (cookie) takes precedence over the browser's
    # Accept-Language header. Falls back to the default locale.
    def requested_locale
      locale_from_cookie || locale_from_browser || I18n.default_locale
    end

    def locale_from_cookie
      locale = cookies[:locale]&.to_sym
      locale if I18n.available_locales.include?(locale)
    end

    def locale_from_browser
      AcceptLanguage.locale_from(
        request.headers['Accept-Language'],
        I18n.available_locales,
      )
    end
  end
end
