class LocaleSelector::Component < ViewComponent::Base
  # Languages are shown in their own native name, regardless of the current
  # UI language (common convention for language switchers).
  NATIVE_NAMES = { de: 'Deutsch', en: 'English' }.freeze
  private_constant :NATIVE_NAMES

  def initialize(css_extra: nil)
    super()
    @css_extra = css_extra
  end

  attr_reader :css_extra

  # Display order follows NATIVE_NAMES (de, en); any other available locale
  # is appended so none is silently dropped.
  def locales
    ordered = NATIVE_NAMES.keys & I18n.available_locales
    ordered + (I18n.available_locales - ordered)
  end

  def native_name(locale)
    NATIVE_NAMES.fetch(locale, locale.to_s.upcase)
  end

  def current_locale
    I18n.locale
  end

  # The locale a click switches to (cycles through the available locales).
  def next_locale
    list = locales
    list[(list.index(current_locale).to_i + 1) % list.size]
  end
end
