class CardComponent < ViewComponent::Base
  include ApplicationHelper

  def initialize(calculator:, field:, timeframe:)
    super
    @calculator = calculator
    @field = field
    @timeframe = timeframe
  end

  def url_params
    @url_params ||= {
      timeframe: @timeframe,
      field:     @field,
      timestamp: params[:timestamp]
    }.compact
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
    url_params[:field] == request.parameters[:field]
  end

  def value
    @calculator.public_send(@field)
  end

  def default_content
    if @field.in?(%w[solar_price traditional_price profit])
      number_to_eur(value)
    elsif @timeframe == 'now'
      number_to_kw(value)
    else
      number_to_kwh(value)
    end
  end
end
