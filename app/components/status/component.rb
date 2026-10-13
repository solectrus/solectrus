class Status::Component < ViewComponent::Base
  def initialize(time:, status: nil, status_ok: nil)
    super()
    @time = time
    @status = status
    @status_ok = status_ok
  end
  attr_reader :time, :status

  def live?
    time && time > tolerated_delay.ago
  end

  def tolerated_delay
    Influx::PollInterval.current * 2
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

  # A capsule of glass, as iOS shows one on a colored bar
  def outer_class
    'rounded-full px-3 py-1 font-medium ' \
      'bg-white/20 ring-1 ring-inset ring-white/30 text-white ' \
      'dark:bg-white/10 dark:ring-white/15 dark:text-gray-200'
  end

  def dot_class
    if live?
      if status_ok?
        'bg-green-400 dark:bg-green-500'
      else
        'bg-yellow-400 dark:bg-yellow-500'
      end
    else
      'bg-red-400 dark:bg-red-500'
    end
  end
end
