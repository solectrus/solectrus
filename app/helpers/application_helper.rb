module ApplicationHelper
  def banner?
    return false if controller.is_a?(ErrorsController)
    return false if UpdateCheck.instance.skipped_prompt?

    UpdateCheck.instance.prompt? ||
      UpdateCheck.instance.registration_status.in?(%w[unregistered pending])
  end

  def extra_stimulus_controllers(*controller_names)
    content_for :extra_stimulus_controllers, controller_names.join(' ')
  end
end
