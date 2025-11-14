module Sensor
  module Chart
    class Forecast < Base
      # Builds custom X-axis labels for forecast chart
      class LabelBuilder
        LABEL_FONT = 'bold 14px Inter Variable, sans-serif'.freeze
        LABEL_FONT_LARGE = 'bold 20px Inter Variable, sans-serif'.freeze
        LABEL_COLOR = '#475569'.freeze
        LABEL_FONT_SMALL = 'bold 12px Inter Variable, sans-serif'.freeze
        LABEL_FONT_UNIT = '12px Inter Variable, sans-serif'.freeze

        private_constant :LABEL_FONT,
                         :LABEL_FONT_LARGE,
                         :LABEL_COLOR,
                         :LABEL_FONT_SMALL,
                         :LABEL_FONT_UNIT

        attr_reader :forecast_data, :today_analyzer

        def initialize(forecast_data, today_analyzer)
          @forecast_data = forecast_data
          @today_analyzer = today_analyzer
        end

        def build_labels
          forecast_data.map do |date, data|
            {
              x: data[:noon_timestamp],
              lines: [day_label(date), *energy_labels(date, data[:total_kwh])],
            }
          end
        end

        private

        def day_label(date)
          if use_responsive_labels?
            {
              text: short_label_text(date),
              offsetY: 10,
              md: {
                text: long_label_text(date),
                offsetY: 12,
              },
            }
          else
            { text: long_label_text(date), offsetY: 12 }
          end
        end

        def short_label_text(date)
          I18n.l(date, format: '%a')
        end

        def long_label_text(date)
          case date
          when Date.current
            I18n.t('forecast.today')
          when Date.tomorrow
            I18n.t('forecast.tomorrow')
          else
            I18n.l(date, format: '%A')
          end
        end

        def use_responsive_labels?
          forecast_data.size > 3
        end

        def energy_labels(date, kwh)
          return [] unless kwh&.positive?

          if show_remaining_for_today?(date)
            if use_responsive_labels?
              # More than 3 days: Add separate unit label for mobile
              [remaining_kwh_label, kwh_unit_label_responsive]
            else
              [remaining_kwh_label]
            end
          elsif use_responsive_labels?
            # More than 3 days: Show unit inline on desktop, below on mobile
            [kwh_value_label(kwh), kwh_unit_label_responsive]
          else
            # 3 or fewer days: Always show unit below the value
            [kwh_value_label(kwh), kwh_unit_label]
          end
        end

        def show_remaining_for_today?(date)
          date == Date.current && today_analyzer.past_production? &&
            today_analyzer.show_today?
        end

        def remaining_kwh_label
          kwh_value_label(today_analyzer.remaining_kwh)
        end

        def kwh_value_label(kwh)
          {
            text: kwh.to_s,
            font: LABEL_FONT,
            color: LABEL_COLOR,
            offsetY: 38,
            md: {
              text: kwh.to_s,
              font: LABEL_FONT_LARGE,
              color: LABEL_COLOR,
              offsetY: 40,
            },
          }
        end

        def kwh_unit_label
          {
            text: 'kWh',
            font: LABEL_FONT_UNIT,
            color: LABEL_COLOR,
            offsetY: 56,
          }
        end

        def kwh_unit_label_responsive
          {
            text: 'kWh',
            font: LABEL_FONT_UNIT,
            color: LABEL_COLOR,
            offsetY: 56,
          }
        end
      end
    end
  end
end
