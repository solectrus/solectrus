class Status::Component < ViewComponent::Base
  def initialize(time:, status: nil, status_ok: nil)
    super
    @time = time
    @status = status
    @status_ok = status_ok
  end
  attr_reader :time, :status

  def live?
    time && time > tolerated_delay.seconds.ago
  end

  def tolerated_delay
    Rails.configuration.x.influx.poll_interval * 2
  end

  def text
    live? ? live_text : t('.disconnect')
  end

  def live_text
    status.presence || t('.connect')
  end

  def message
    return if live?

    if time
      "#{t('calculator.time')} #{time_ago_in_words(time, include_seconds: true)}"
    else
      t('calculator.blank')
    end
  end

  def status_ok?
    # Fallback when status_ok is not present
    return true if @status_ok.nil?

    @status_ok
  end

  def outer_class
    if status_ok?
      'bg-gray-200 dark:bg-gray-300/75 text-black dark:text-gray-800'
    else
      'bg-orange-100 dark:bg-orange-400/50 text-orange-800 dark:text-orange-200'
    end
  end

  def dot_class
    if live?
      if status_ok?
        'bg-green-500 dark:bg-green-700'
      else
        'bg-orange-400 dark:bg-orange-800'
      end
    else
      'bg-red-500 dark:bg-red-700'
    end
  end
end
