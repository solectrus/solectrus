class Card::Component < ViewComponent::Base
  with_content_areas :tippy, :extra

  def initialize(field:, signal: nil, klasses: nil, value: nil)
    super
    @field = field
    @signal = signal
    @klasses = klasses
    @value = value
  end

  attr_accessor :field, :signal, :klasses, :value

  def url_params
    @url_params ||= {
      field:     field,
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
    @title ||= I18n.t("calculator.#{field}")
  end

  def current_value?
    current? && timeframe == 'now'
  end

  def current?
    params[:field] == field
  end

  def icon
    tag.i class: "#{icon_class} fa-2x"
  end

  def icon_class
    {
      'inverter_power'       => 'fas fa-sun',
      'wallbox_charge_power' => 'fas fa-car',
      'house_power'          => 'fas fa-home',
      'grid_power_plus'      => 'fas fa-plug',
      'grid_power_minus'     => 'fas fa-plug'
    }[field]
  end

  def signal_class
    if signal.nil?
      'bg-gray-500'
    elsif signal.in?([true, false])
      signal ? 'bg-green-500' : 'bg-red-500'
    elsif signal.is_a?(Numeric)
      'bg-red-500'
    end
  end

  def percent_green
    case signal
    when true then 100
    when false then 0
    else signal
    end
  end

  def percent_red
    return unless percent_green

    100 - percent_green
  end
end
