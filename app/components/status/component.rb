class Status::Component < ViewComponent::Base
  # A reading younger than `max_age` is live. Without `live_expected`, as for
  # a page whose values are states, the status reads "Connected" instead of
  # "Live", and an older reading warns instead of counting as missing.
  def initialize(time:, max_age:, status: nil, status_ok: nil, live_expected: true)
    super()
    @time = time
    @max_age = max_age
    @status = status
    @status_ok = status_ok
    @live_expected = live_expected
  end
  attr_reader :time, :max_age, :status

  def live?
    time && time > max_age.ago
  end

  # :ok, :warning (a status that is not ok, or an old state) or :missing
  def state
    if live?
      status_ok? ? :ok : :warning
    elsif time && !@live_expected
      :warning
    else
      :missing
    end
  end

  def text
    state == :missing ? t('.disconnect') : live_text
  end

  def live_text
    Sensor::ValueFormatter.new(status, unit: :string).to_s.presence ||
      t(@live_expected ? '.live' : '.connected')
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

  # A capsule of glass on a colored bar
  def outer_class
    'rounded-full px-3 py-1 font-medium ' \
      'bg-white/20 ring-1 ring-inset ring-white/30 text-white ' \
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
