class ChartLoader::Component < ViewComponent::Base # rubocop:disable Metrics/ClassLength
  def initialize(sensor:, timeframe:)
    super
    @sensor = sensor
    @timeframe = timeframe
  end
  attr_reader :sensor, :timeframe

  def data
    @data ||=
      begin
        class_name = "ChartData::#{sensor.to_s.camelize}"
        # Example: :inverter_power -> ChartData::InverterPower

        if Object.const_defined?(class_name)
          Object.const_get(class_name).new(timeframe:)
        else
          # :nocov:
          raise NotImplementedError,
                "ChartData::#{sensor.to_s.camelize} not implemented"
          # :nocov:
        end
      end
  end

  def options # rubocop:disable Metrics/MethodLength
    {
      maintainAspectRatio: false,
      plugins: {
        legend: false,
        tooltip: {
          # Match colors to Tippy theme
          backgroundColor: 'rgba(255, 255, 255, 1.0)',
          titleColor: '#222',
          bodyColor: '#222',
          footerColor: '#222',
          borderColor: 'rgba(0, 8, 16, 0.6)',
          borderWidth: 1,
          #
          displayColors: false,
          titleFont: {
            size: 15,
          },
          bodyFont: {
            size: 18,
          },
          caretPadding: 15,
          caretSize: 10,
        },
        zoom:
          (
            if timeframe.short?
              { zoom: { drag: { enabled: true }, mode: 'x' } }
            else
              {}
            end
          ),
      },
      animation: {
        easing: 'easeOutQuad',
        duration: 300,
      },
      interaction: {
        intersect: false,
        mode: 'index',
      },
      elements: {
        point: {
          radius: 0,
          hitRadius: 5,
          hoverRadius: 5,
        },
      },
      scales: {
        x: {
          stacked: true,
          grid: {
            drawOnChartArea: false,
          },
          type: 'time',
          ticks:
            {
              now: {
                stepSize: 15,
                maxRotation: 0,
              },
              day: {
                stepSize: 3,
                maxRotation: 0,
              },
              week: {
                stepSize: 1,
                maxRotation: 0,
              },
              month: {
                stepSize: 2,
                maxRotation: 0,
              },
              year: {
                stepSize: 1,
                maxRotation: 0,
              },
              all: {
                stepSize: 1,
                maxRotation: 0,
              },
            }[
              timeframe.id
            ],
          time:
            {
              now: {
                unit: 'minute',
                displayFormats: {
                  minute: 'HH:mm',
                },
                tooltipFormat: 'HH:mm:ss',
              },
              day: {
                unit: 'hour',
                displayFormats: {
                  hour: 'HH:mm',
                },
                tooltipFormat: 'HH:mm',
              },
              week: {
                unit: 'day',
                displayFormats: {
                  day: 'eee',
                },
                tooltipFormat: 'eeee, dd.MM.yyyy',
                round: 'day',
              },
              month: {
                unit: 'day',
                displayFormats: {
                  day: 'd',
                },
                tooltipFormat: 'eeee, dd.MM.yyyy',
                round: 'day',
              },
              year: {
                unit: 'month',
                displayFormats: {
                  month: 'MMM',
                },
                tooltipFormat: 'MMMM yyyy',
                round: 'month',
              },
              all: {
                unit: 'year',
                displayFormats: {
                  year: 'yyyy',
                },
                tooltipFormat: 'yyyy',
                round: 'year',
              },
            }[
              timeframe.id
            ],
        },
        y: {
          max: max_y,
          min: min_y,
          suggestedMax: suggested_max_y,
          suggestedMin: suggested_min_y,
          ticks: {
            beginAtZero: true,
            maxTicksLimit: 4,
          },
        },
      },
    }
  end

  def type
    (timeframe.short? ? 'line' : 'bar').inquiry
  end

  def unit
    case sensor
    when :battery_soc, :car_battery_soc, :autarky, :self_consumption
      '&percnt;'.html_safe
    when :case_temp
      '&deg;C'.html_safe
    when :co2_reduction
      timeframe.short? ? 'g/h' : 'kg'
    else
      timeframe.short? ? 'kW' : 'kWh'
    end
  end

  def max_y
    sensor.in?(%i[self_consumption autarky]) ? 100 : nil
  end

  def suggested_max_y
    sensor.in?(%i[battery_soc car_battery_soc]) ? 100 : nil
  end

  def min_y
    0 if sensor.in?(%i[battery_soc car_battery_soc self_consumption autarky])
  end

  def suggested_min_y
    sensor == :case_temp ? 20 : nil
  end
end
