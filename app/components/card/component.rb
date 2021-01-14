class Card::Component < ViewComponent::Base
  with_content_areas :tippy

  def initialize(calculator:, field:, timeframe: nil, size: :default)
    super
    @calculator = calculator
    @field = field
    @timeframe = timeframe
    @size = size
  end

  attr_accessor :size, :timeframe

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
    if @field.in?(%w[bat_fuel_charge])
      Number::Component.new(value: value).to_percent
    elsif @field.in?(%w[autarky])
      Number::Component.new(value: value).to_percent(max_precision: 0)
    elsif @field.in?(%w[solar_price traditional_price profit])
      Number::Component.new(value: value).to_eur
    elsif @timeframe == 'now'
      Number::Component.new(value: value).to_kw
    else
      Number::Component.new(value: value).to_kwh
    end
  end
end
