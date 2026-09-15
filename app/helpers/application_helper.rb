module ApplicationHelper
  # The banner asks for the missing registration, so it needs both halves of
  # that sentence: a registration that is missing, and a reminder that is due.
  # The update server sends the reminder date only while the registration is
  # missing, but the banner has no text for any other case, so the second half
  # is asked for here instead of assumed.
  #
  # It reads its own snooze and not the one of the sponsoring prompt. The two
  # questions are answered in different places and end differently: without a
  # sponsorship the app keeps working, without a registration it does not.
  def banner?
    return false if controller.is_a?(ErrorsController)
    return false if UpdateCheck.snoozed_banner?
    return false unless UpdateCheck.unregistered?

    UpdateCheck.registration_reminder_due?
  end

  def extra_stimulus_controllers(*controller_names)
    content_for :extra_stimulus_controllers, controller_names.join(' ')
  end

  def controller_namespace
    @controller_namespace ||= controller_path.split('/').first
  end

  def frame_id(prefix, timeframe: nil)
    # Hack to make this work in the preview, too
    timeframe ||= controller.__send__ :timeframe

    # Use timeframe as string and replace dots with hyphens
    # Note: Timeframe can be a range like "2022-06-05..2022-06-20"
    timeframe_identifier = timeframe.original_string.tr('.', '-')

    "#{controller_namespace}-#{prefix}-#{timeframe_identifier}"
  end

  # The theme the visitor picked, written by the theme selector. A cookie and
  # not localStorage, so the server can render the right theme right away
  # instead of letting the browser correct it after the first paint. nil means
  # the visitor follows the operating system.
  #
  # A helper and not a controller method: the login and OAuth pages use the
  # blank layout but do not inherit from ApplicationController.
  def chosen_theme
    cookies[:theme]
  end

  # The classes the stylesheet keys its colors off: the theme, and the palette
  # the sensor colors come from. Both ride on a cookie, so the first response
  # carries them and the browser paints the right colors at once. Without the
  # palette class, a visitor on the contrast palette sees the standard sensor
  # colors until the theme selector connects.
  def html_theme_classes
    contrast =
      ApplicationPolicy.themes? && cookies[:color_palette] == 'contrast'

    class_names(
      ThemeConfig.x.html_class(chosen_theme),
      'palette-contrast' => contrast,
    ).presence
  end

  # Paints the frame color before the stylesheet arrives, so the page does not
  # start white. An inline style, because that is the only thing the browser
  # has at that moment. The variable takes over as soon as the stylesheet is
  # there and follows the theme from then on, including a switch without a
  # reload. The value behind the comma only fills the gap before that.
  def chrome_background_style
    "background-color: var(--color-chrome, #{ThemeConfig.x.color(chosen_theme)})"
  end
end
