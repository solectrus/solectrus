module AutoLocale
  extend ActiveSupport::Concern

  included do
    around_action :switch_locale

    private

    def switch_locale(&)
      locale =
        http_accept_language.compatible_language_from(I18n.available_locales) ||
          I18n.default_locale

      I18n.with_locale(locale, &)
    end
  end
end
