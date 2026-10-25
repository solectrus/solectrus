class Status::Component < ViewComponent::Base
  # A reading younger than `max_age` is live. `on_bar: false` gives the look
  # for the content of the page instead of the colored bar.
  def initialize(time:, max_age:, status: nil, status_ok: nil, on_bar: true)
    super()
    @time = time
    @max_age = max_age
    @status = status
    @status_ok = status_ok
    @on_bar = on_bar
  end
  attr_reader :time, :max_age, :status

  def live?
    time && time > max_age.ago
  end

  # :ok, :warning (a status that is not ok) or :missing
  def state
    return :missing unless live?

    status_ok? ? :ok : :warning
  end

  def text
    state == :missing ? t('.disconnect') : live_text
  end

  def live_text
    Sensor::ValueFormatter.new(status, unit: :string).to_s.presence ||
      t('.live')
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

  # A capsule: of glass on a colored bar, filled like a chip on the page. The
  # text comes from the system and can be long, the capsule grows with it.
  def outer_class
    base = 'rounded-full px-3 py-1 text-sm font-medium'
    return "#{base} bg-fill dark:bg-fill-strong text-fg-secondary" unless @on_bar

    "#{base} bg-white/20 ring-1 ring-inset ring-white/30 text-white " \
      'dark:bg-white/10 dark:ring-white/15 dark:text-gray-200'
  end

  DOT_CLASSES = {
    ok: 'bg-green-400 dark:bg-green-500',
    warning: 'bg-yellow-400 dark:bg-yellow-500',
    missing: 'bg-red-400 dark:bg-red-500',
  }.freeze
  private_constant :DOT_CLASSES

  def dot_class = DOT_CLASSES[state]
end
