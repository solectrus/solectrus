module Sensor
  module Forecast
    # Builds custom X-axis labels for forecast charts
    class LabelBuilder
      LABEL_FONT = 'bold 14px Inter Variable, sans-serif'.freeze
      LABEL_FONT_LARGE = 'bold 20px Inter Variable, sans-serif'.freeze
      LABEL_COLOR = '#475569'.freeze
      LABEL_FONT_UNIT = '12px Inter Variable, sans-serif'.freeze
      LABEL_FONT_MIN = '14px Inter Variable, sans-serif'.freeze
      LABEL_FONT_MIN_LARGE = '16px Inter Variable, sans-serif'.freeze

      private_constant :LABEL_FONT,
                       :LABEL_FONT_LARGE,
                       :LABEL_COLOR,
                       :LABEL_FONT_UNIT,
                       :LABEL_FONT_MIN,
                       :LABEL_FONT_MIN_LARGE

      def initialize(forecast_data, today_analyzer, value_key:)
        @forecast_data = forecast_data
        @today_analyzer = today_analyzer
        @value_key = value_key
      end

      attr_reader :forecast_data, :today_analyzer, :value_key

      def build_labels
        forecast_data.map do |date, data|
          {
            x: data[:noon_timestamp],
            lines: [day_label(date), *labels_for(date, data)],
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
        date == Date.current ? I18n.t('forecast.today') : I18n.l(date, format: '%A')
      end

      def use_responsive_labels?
        forecast_data.size > 3
      end

      def labels_for(date, data)
        if value_key == :temp_range
          temp_range_labels(data[:min_temp], data[:max_temp])
        else
          value_labels(date, data[value_key])
        end
      end

      # Max above min, like a weather app. The degree sign replaces the
      # unit line, so both values fit into the narrow columns on a phone.
      def temp_range_labels(min_temp, max_temp)
        return [] unless min_temp && max_temp

        [
          temp_label(max_temp, font: LABEL_FONT, md_font: LABEL_FONT_LARGE, offsets: [38, 40]),
          temp_label(min_temp, font: LABEL_FONT_MIN, md_font: LABEL_FONT_MIN_LARGE, offsets: [58, 66]),
        ]
      end

      # The number alone is centered, the degree sign follows it as suffix.
      # Otherwise the number would sit left of the day name.
      def temp_label(value, font:, md_font:, offsets:)
        line = { text: value.round.to_s, suffix: '°', color: LABEL_COLOR }

        line.merge(
          font:,
          offsetY: offsets.first,
          md: line.merge(font: md_font, offsetY: offsets.last),
        )
      end

      def value_labels(date, value)
        return [] unless value

        text = format_value(calculate_display_value(date, value))

        if use_responsive_labels?
          [value_label(text), unit_label_responsive]
        else
          [value_label(text), unit_label]
        end
      end

      def calculate_display_value(date, value)
        # For energy charts with today analyzer
        if value_key == :total_wh && show_total_for_today?(date)
          today_analyzer.total_wh
        else
          value
        end
      end

      def show_total_for_today?(date)
        date == Date.current && today_analyzer.respond_to?(:past_production?) &&
          today_analyzer.past_production? && today_analyzer.show_today?
      end

      def value_label(text)
        {
          text:,
          font: LABEL_FONT,
          color: LABEL_COLOR,
          offsetY: 38,
          md: {
            text:,
            font: LABEL_FONT_LARGE,
            color: LABEL_COLOR,
            offsetY: 40,
          },
        }
      end

      def format_value(value)
        ActiveSupport::NumberHelper.number_to_rounded(value.to_f / 1000, precision: 0)
      end

      def unit
        'kWh'
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
