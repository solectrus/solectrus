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

  def frame_id(prefix, timeframe: self.timeframe)
    "#{controller_namespace}-#{prefix}-#{timeframe}"
  end
end
