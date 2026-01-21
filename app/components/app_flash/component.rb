class AppFlash::Component < ViewComponent::Base
  def initialize(alert: nil, notice: nil)
    super()
    @alert = alert
    @notice = notice
  end

  attr_reader :alert, :notice

  def background_class
    if notice
      'bg-emerald-50 dark:bg-emerald-800 border-emerald-500 dark:border-emerald-600'
    elsif alert
      'bg-red-50 dark:bg-red-800 border-red-500 dark:border-red-600'
    end
  end

  def text_class
    if notice
      'text-emerald-800 dark:text-emerald-300'
    elsif alert
      'text-red-700 dark:text-red-200'
    end
  end

  def icon_class
    if notice
      'far fa-circle-check text-emerald-800 dark:text-emerald-300'
    elsif alert
      'fas fa-circle-exclamation text-red-700 dark:text-red-200'
    end
  end

  def text
    notice || alert
  end
end
