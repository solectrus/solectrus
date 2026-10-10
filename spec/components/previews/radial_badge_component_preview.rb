# @label RadialBadge
# @logical_path data_display
# @display max_width 6.5rem
class RadialBadgeComponentPreview < ViewComponent::Preview
  # Autarky: 0-33% negative, 34-66% warning, 67-100% positive
  # Battery SOC: 0-5% negative, 6-20% warning, 21-100% positive

  # @!group Overview
  def autarky_negative
    radial_badge(:autarky, 33)
  end

  def autarky_warning
    radial_badge(:autarky, 34)
  end

  def autarky_positive
    radial_badge(:autarky, 67)
  end

  def autarky_max
    radial_badge(:autarky, 100)
  end

  def autarky_without_value
    radial_badge(:autarky, nil)
  end

  def battery_soc_min
    radial_badge(:battery_soc, 0)
  end

  def battery_soc_negative
    radial_badge(:battery_soc, 5)
  end

  def battery_soc_warning
    radial_badge(:battery_soc, 20)
  end

  def battery_soc_positive
    radial_badge(:battery_soc, 21)
  end

  def self_consumption_quote
    radial_badge(:self_consumption_quote, 70)
  end

  def case_temp
    render_with_template(locals: { data: data_for(:case_temp, 35) })
  end
  # @!endgroup

  private

  def radial_badge(sensor_name, value)
    render RadialBadge::Component.new(
             sensor_name,
             data: data_for(sensor_name, value),
           )
  end

  def data_for(sensor_name, value)
    Sensor::Data::Single.new(
      { sensor_name => value&.to_f },
      timeframe: Timeframe.now,
    )
  end
end
