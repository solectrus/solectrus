module ApplicationHelper
  def banner?
    return false if controller.is_a?(ErrorsController)
    return false if UpdateCheck.skipped_prompt?

    UpdateCheck.unregistered?
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
    timeframe_identifier = timeframe.to_s.tr('.', '-')

    "#{controller_namespace}-#{prefix}-#{timeframe_identifier}"
  end
end
