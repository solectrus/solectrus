class Status::Component < ViewComponent::Base
  def initialize(time:, system_status: nil, system_status_ok: nil)
    super
    @time = time
    @system_status = system_status
    @system_status_ok = system_status_ok
  end
  attr_reader :time, :system_status

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
    system_status.presence || t('.connect')
  end

  def message
    return if live?

    if time
      "#{t('calculator.time')} #{time_ago_in_words(time, include_seconds: true)}"
    else
      t('calculator.blank')
    end
  end

  def system_status_ok?
    # Fallback when system_status_ok is not present
    return true if @system_status_ok.nil?

    @system_status_ok
  end

  def outer_class
    if system_status_ok?
      'bg-indigo-100 dark:bg-indigo-300 text-black dark:text-indigo-950'
    else
      'bg-orange-100 text-orange-800'
    end
  end

  def dot_class
    if live?
      if system_status_ok?
        'bg-green-500 dark:bg-green-700'
      else
        'bg-orange-400 dark:bg-orange-600'
      end
    else
      'bg-red-500 dark:bg-red-700'
    end
  end
end
