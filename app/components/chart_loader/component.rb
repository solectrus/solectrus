class ChartLoader::Component < ViewComponent::Base # rubocop:disable Metrics/ClassLength
  def initialize(sensor:, timeframe:, variant: nil)
    super
    @sensor = sensor
    @timeframe = timeframe
    @variant = variant
  end
  attr_reader :sensor, :timeframe, :variant

  def data
    @data ||=
      case sensor.to_s
      when /custom_power_\d{2}/
        ChartData::CustomPower.new(timeframe:, sensor:)
      when /inverter_power_\d{1}/
        ChartData::InverterPower.new(timeframe:, sensor:)
      when 'inverter_power'
        ChartData::InverterPower.new(timeframe:, sensor:, variant:)
      else
        Object.const_get("ChartData::#{sensor.to_s.camelize}").new(timeframe:)
        # Example: :house_power -> ChartData::HousePower
      end
  end

  delegate :type, to: :data

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
        crosshair: timeframe.short?,
      },
      animation: {
        easing: 'easeOutQuad',
        duration: 300,
      },
      interaction: {
        # On bars (long timeframe) we want interaction when hovering on a bar, not above them
        intersect: !timeframe.short?,
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
          adapters: {
            date: {
              zone: Time.zone.name,
            },
          },
          ticks:
            {
              now: {
                stepSize: 15,
                maxRotation: 0,
              },
              hours: {
                stepSize: 3,
                maxRotation: 0,
              },
              day: {
                stepSize: 3,
                maxRotation: 0,
              },
              days: {
                stepSize: (timeframe.relative_count.to_i > 14 ? 2 : 1),
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
              months: {
                stepSize: 1,
                maxRotation: 0,
              },
              year: {
                stepSize: 1,
                maxRotation: 0,
              },
              years: {
                stepSize: 1,
                maxRotation: 0,
              },
              all: {
                stepSize: 1,
                maxRotation: 0,
              },
            }[
              timeframe.id,
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
              hours: {
                unit: 'hour',
                displayFormats: {
                  hour: 'HH:mm',
                },
                tooltipFormat: 'HH:mm',
              },
              day: {
                unit: 'hour',
                displayFormats: {
                  hour: 'HH:mm',
                },
                tooltipFormat: 'HH:mm',
              },
              days: {
                unit: 'day',
                displayFormats: {
                  day:
                    case timeframe.relative_count.to_i
                    when ..8
                      'ccc'
                    when 9..31
                      'd'
                    when 32..280
                      'd. LLL'
                    else
                      'LLL yyyy'
                    end,
                },
                tooltipFormat: 'cccc, dd.MM.yyyy',
                round: 'day',
              },
              week: {
                unit: 'day',
                displayFormats: {
                  day: 'ccc',
                },
                tooltipFormat: 'cccc, dd.MM.yyyy',
                round: 'day',
              },
              month: {
                unit: 'day',
                displayFormats: {
                  day: 'd',
                },
                tooltipFormat: 'cccc, dd.MM.yyyy',
                round: 'day',
              },
              months: {
                unit: 'month',
                displayFormats: {
                  month: 'LLL',
                },
                tooltipFormat: 'MMMM yyyy',
                round: 'month',
              },
              year: {
                unit: 'month',
                displayFormats: {
                  month: 'LLL',
                },
                tooltipFormat: 'MMMM yyyy',
                round: 'month',
              },
              years: {
                unit: 'year',
                displayFormats: {
                  year: 'yyyy',
                },
                tooltipFormat: 'yyyy',
                round: 'year',
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
              timeframe.id,
            ],
        },
        y: {
          suggestedMax: suggested_max_y,
          suggestedMin: suggested_min_y,
          ticks: {
            beginAtZero: true,
            maxTicksLimit: 10,
          },
        },
      },
    }.deep_merge(data.options)
  end

  def unit
    case sensor
    when :battery_soc, :car_battery_soc, :autarky, :self_consumption
      '&percnt;'.html_safe
    when :case_temp
      '&deg;C'.html_safe
    when :co2_reduction
      timeframe.short? ? 'g/h' : 'g'
    else
      timeframe.short? ? 'W' : 'Wh'
    end
  end

  def suggested_max_y
    data.suggested_max
  end

  def suggested_min_y
    data.suggested_min
  end
end
