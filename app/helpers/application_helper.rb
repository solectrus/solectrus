module ApplicationHelper
  def banner?
    (
      UpdateCheck.instance.registration_status.in?(%w[unregistered pending]) ||
        UpdateCheck.instance.prompt?
    ) && !UpdateCheck.instance.skipped_prompt?
  end
end
