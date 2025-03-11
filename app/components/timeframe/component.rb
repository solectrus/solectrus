class Timeframe::Component < ViewComponent::Base
  def initialize(timeframe:)
    super
    @timeframe = timeframe
  end
  attr_reader :timeframe

  def next_path
    url_for(
      controller: "#{helpers.controller_namespace}/home",
      sensor: params[:sensor],
      timeframe: timeframe.next,
    )
  end

  def prev_path
    url_for(
      controller: "#{helpers.controller_namespace}/home",
      sensor: params[:sensor],
      timeframe: timeframe.prev,
    )
  end
end
