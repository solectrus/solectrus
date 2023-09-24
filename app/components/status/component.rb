class Status::Component < ViewComponent::Base
  def initialize(time:, current_state: nil, current_state_ok: nil)
    super
    @time = time
    @current_state = current_state
    @current_state_ok = current_state_ok
  end
  attr_reader :time, :current_state

  def live?
    time && time > 10.seconds.ago
  end

  def text
    live? ? live_text : t('.disconnect')
  end

  def live_text
    current_state.presence || t('.connect')
  end

  def message
    return if live?

    if time
      "#{t('calculator.time')} #{time_ago_in_words(time, include_seconds: true)}"
    else
      t('calculator.blank')
    end
  end

  def current_state_ok?
    # Fallback when current_state_ok is not present
    return true if @current_state_ok.nil?

    @current_state_ok
  end

  def outer_class
    if current_state_ok?
      'bg-indigo-50 text-black'
    else
      'bg-orange-100 text-orange-800'
    end
  end

  def ping_classes
    if live?
      if current_state_ok?
        %w[bg-green-400 bg-green-500]
      else
        %w[bg-orange-300 bg-orange-400]
      end
    else
      %w[bg-red-400 bg-red-500]
    end
  end
end
