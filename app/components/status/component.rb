class Status::Component < ViewComponent::Base
  def initialize(time:)
    super
    @time = time
  end
  attr_reader :time

  def live?
    time && time > 10.seconds.ago
  end

  def text
    live? ? 'LIVE' : 'FAIL'
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
