class Card::Component < ViewComponent::Base
  with_content_areas :tippy

  def initialize(field:, size: :default)
    super
    @field = field
    @size = size
  end

  attr_accessor :size

  def url_params
    @url_params ||= {
      field:     @field,
      timeframe: timeframe,
      timestamp: timestamp
    }.compact
  end

  def timeframe
    params[:timeframe]
  end

  def timestamp
    params[:timestamp]
  end

  def url
    Rails.application.routes.recognize_path(root_path(url_params))
  rescue ActionController::RoutingError
    nil
  end

  def title
    @title ||= I18n.t("calculator.#{@field}")
  end

  def current?
    params[:field] == @field
  end
end
