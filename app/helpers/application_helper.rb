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
end
