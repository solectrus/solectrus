module Sensor
  module Forecast
    # Builds custom X-axis labels for forecast charts
    class LabelBuilder
      LABEL_FONT = 'bold 14px Inter Variable, sans-serif'.freeze
      LABEL_FONT_LARGE = 'bold 20px Inter Variable, sans-serif'.freeze
      LABEL_COLOR = '#475569'.freeze
      LABEL_FONT_UNIT = '12px Inter Variable, sans-serif'.freeze

      private_constant :LABEL_FONT,
                       :LABEL_FONT_LARGE,
                       :LABEL_COLOR,
                       :LABEL_FONT_UNIT

      def initialize(
        forecast_data,
        today_analyzer,
        value_key:,
        unit:,
        precision:
      )
        @forecast_data = forecast_data
        @today_analyzer = today_analyzer
        @value_key = value_key
        @unit = unit
        @precision = precision
      end

      attr_reader :forecast_data, :today_analyzer, :value_key, :unit, :precision

      def build_labels
        forecast_data.map do |date, data|
          {
            x: data[:noon_timestamp],
            lines: [day_label(date), *value_labels(date, data[value_key])],
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

      def value_labels(date, value)
        return [] unless value_present?(value)

        display_value = calculate_display_value(date, value)

        if use_responsive_labels?
          [value_label(display_value), unit_label_responsive]
        else
          [value_label(display_value), unit_label]
        end
      end

      def value_present?(value)
        return value&.positive? if value.is_a?(Numeric)

        value.present?
      end

      def calculate_display_value(date, value)
        # For energy charts with today analyzer
        if value_key == :total_kwh && show_total_for_today?(date)
          today_analyzer.total_kwh
        else
          value
        end
      end

      def show_total_for_today?(date)
        date == Date.current && today_analyzer.respond_to?(:past_production?) &&
          today_analyzer.past_production? && today_analyzer.show_today?
      end

      def value_label(value)
        formatted_value = format_value(value)

        {
          text: formatted_value,
          font: LABEL_FONT,
          color: LABEL_COLOR,
          offsetY: 38,
          md: {
            text: formatted_value,
            font: LABEL_FONT_LARGE,
            color: LABEL_COLOR,
            offsetY: 40,
          },
        }
      end

      def format_value(value)
        ActiveSupport::NumberHelper.number_to_rounded(value, precision:)
      end

      def unit_label
        { text: unit, font: LABEL_FONT_UNIT, color: LABEL_COLOR, offsetY: 56 }
      end

      def unit_label_responsive
        { text: unit, font: LABEL_FONT_UNIT, color: LABEL_COLOR, offsetY: 56 }
      end
    end
  end
end
