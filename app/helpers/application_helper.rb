module ApplicationHelper
  def banner?
    return false if controller.is_a?(ErrorsController)

    UpdateCheck.unregistered?
  end

  def extra_stimulus_controllers(*controller_names)
    content_for :extra_stimulus_controllers, controller_names.join(' ')
  end
end
