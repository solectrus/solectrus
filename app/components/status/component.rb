class Status::Component < ViewComponent::Base
  def initialize(time:, current_state: nil)
    super
    @time = time
    @current_state = current_state
  end
  attr_reader :time, :current_state

  def live?
    time && time > 10.seconds.ago
  end

  def text
    live? ? live_text : 'FAIL'
  end

  def live_text
    current_state.presence || 'LIVE'
  end

  def message
    return if live?

    if time
      "#{t('calculator.time')} #{time_ago_in_words(time, include_seconds: true)}"
    else
      t('calculator.blank')
    end
  end

  def background_classes
    live? ? %w[bg-green-400 bg-green-500] : %w[bg-red-400 bg-red-500]
  end
end
