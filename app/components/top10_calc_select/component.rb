class Top10CalcSelect::Component < ViewComponent::Base
  def initialize(calc:, sensor:)
    super()
    @calc = calc
    @sensor = sensor
  end

  attr_reader :calc, :sensor

  def dropdown_items
    sensor.allowed_aggregations.map do |agg|
      MenuItem::Component.new(
        name: calc_label_long(agg.to_s),
        href: helpers.url_for(**helpers.permitted_params, calc: agg.to_s, only_path: true),
        current: calc == agg.to_s,
      )
    end
  end

  def button_text
    calc_label_short(calc)
  end

  private

  def calc_label_short(calc_option)
    t(".#{calc_option}.short", default: calc_option.to_s)
  end

  def calc_label_long(calc_option)
    t(".#{calc_option}.long", default: calc_option.to_s.capitalize)
  end
end
