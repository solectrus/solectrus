class Status::Component < ViewComponent::Base
  def initialize(time:, status: nil, status_ok: nil)
    super()
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
    Sensor::ValueFormatter.new(status, unit: :string).to_s.presence ||
      t('.connect')
  end

  def message
    return if live?

    if time
      "#{t('data.time')} #{time_ago_in_words(time, include_seconds: true)}"
    else
      t('data.blank')
    end
  end

  def status_ok?
    # Fallback when status_ok is not present
    return true if @status_ok.nil?

    @status_ok
  end

  def outer_class
    'bg-gray-200 dark:bg-gray-300/75 text-black dark:text-gray-800'
  end

  def dot_class
    if live?
      if status_ok?
        'bg-green-600 dark:bg-green-700'
      else
        'bg-yellow-600 dark:bg-yellow-700'
      end
    else
      'bg-red-600 dark:bg-red-700'
    end
  end
end
