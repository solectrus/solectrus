module ApplicationHelper
  def banner?
    (
      UpdateCheck.instance.registration_status.in?(%w[unregistered pending]) ||
        UpdateCheck.instance.prompt?
    ) && !UpdateCheck.instance.skipped_prompt?
  end

  def extra_stimulus_controllers(*controller_names)
    content_for :extra_stimulus_controllers, controller_names.join(' ')
  end
end
