class Card::Component < ViewComponent::Base
  with_content_areas :tippy, :extra

  def initialize(field:, signal: nil, klasses: nil)
    super
    @field = field
    @signal = signal
    @klasses = klasses
  end

  attr_accessor :field, :signal, :klasses

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

  def value_options
    if current? && timeframe == 'now'
      { data: { refresh_target: 'current' } }
    else
      {}
    end
  end

  def signal_class
    if signal.nil?
      'bg-gray-500'
    else
      signal ? 'bg-green-500' : 'bg-red-500'
    end
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
      'grid_power_minus'     => 'fas fa-bolt'
    }[field]
  end

  def content_class
    if current?
      [ signal_class, 'p-2 md:p-3 rounded border-4 border-black shadow', klasses ]
    else
      [ signal_class, 'p-2 md:p-3 rounded border-4 border-transparent', klasses ]
    end
  end
end
