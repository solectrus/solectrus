# The four home pages: power balance, house, heat pump and inverter. Which
# page shows a sensor is a property of the sensor (`home_pages` in its
# definition), so this module only collects the answers.
#
# Three questions read them. A controller asks "does my page show this
# sensor?" to reject a foreign name in the URL (see
# HomePageController#supported_sensor?), SensorPathHelper asks "which page
# shows this sensor?" to build a link, and the chart dropdown of a page asks
# "which sensors are mine?". A link can therefore not point at a page that
# sends the user away again.
#
# The fourth question is about the page itself: the settings can switch it
# off, and `available?` answers for the controller and for a link alike.
module Sensor::HomePage
  # The setting that switches a page off. The power balance is the start page
  # and has none.
  PAGES = {
    balance: nil,
    heatpump: :enable_heatpump,
    inverter: :enable_multi_inverter,
    house: :enable_custom_consumer,
  }.freeze
  private_constant :PAGES

  class << self
    def all = PAGES.keys

    # Whether the settings switch this page on.
    def available?(key)
      setting = page_setting(key)

      setting.nil? || Setting.public_send(setting)
    end

    # The sensors of a page, in the order the installation lists them. The
    # menu of the page arranges them, see ChartDropdownLogic.
    def sensor_names(key)
      page_setting(key) # rejects a page that does not exist

      Sensor::Config.chart_sensors.filter_map do |sensor|
        sensor.name if sensor.home_pages.include?(key)
      end
    end

    # The page a link for this sensor has to point at. A sensor names its
    # pages in the order it prefers them, and a page the settings switched off
    # is skipped, because it would only redirect to the start page. If the
    # settings switched every page of the sensor off, the power balance takes
    # the sensor over, so a link cannot dead-end.
    def page_for(sensor_name) = target_page(pages_for(sensor_name))

    # Whether this page renders the sensor: it either lists the sensor, or it
    # is the page a link for the sensor points at. A name no sensor claims
    # gets no page, so a hand-edited URL still cannot pick one.
    def accepts?(key, sensor_name)
      pages = pages_for(sensor_name)
      return false if pages.empty?

      pages.include?(key) || target_page(pages) == key
    end

    private

    def target_page(pages) = pages.find { available?(it) } || :balance

    # The setting that switches the page off, nil for the start page. An
    # unknown key comes from the code, never from a request, so it raises.
    def page_setting(key)
      PAGES.fetch(key) { raise ArgumentError, "Unknown home page: #{key}" }
    end

    # A name a page never offers has no pages. A half of a combined chart is
    # such a name and still has to answer, so the lookup hands it to the chart
    # that offers it, see Sensor::Config#chart_sensor_by_name.
    def pages_for(sensor_name)
      Sensor::Config.chart_sensor_by_name[sensor_name]&.home_pages || []
    end
  end
end
