module Sensor
  module Definitions
    class Colors
      def initialize(meta_data)
        @meta_data = meta_data
      end

      def color(background: nil, text: nil, border: nil, hatch_fill: nil, &block)
        if block
          validate_no_options!(background, text, border, hatch_fill)
          return apply_dynamic_color(block)
        end

        return apply_gradient_color(background, text, border, hatch_fill) if gradient?(background)
        return apply_static_color(background, text, border, hatch_fill) if background && text

        raise ArgumentError, 'color requires either a block or background and text'
      end

      def gradient(from:, to:, start:, stop:)
        {
          type: :gradient,
          from:,
          to:,
          start:,
          stop:,
        }
      end

      private

      attr_reader :meta_data

      def normalize_color_scale(scale)
        scale
          .map { |value, classes| [Float(value), classes] }
          .sort_by(&:first)
      rescue ArgumentError, TypeError
        raise ArgumentError, 'color scale must use numeric keys'
      end

      def apply_dynamic_color(block)
        # Block receives a value (e.g., percent) and must return hash with:
        # :background, :text, and optionally :border
        meta_data[:color_dynamic] = block
      end

      def apply_static_color(background, text_class, border_class, hatch_fill)
        unless background.is_a?(String) && text_class.is_a?(String)
          raise ArgumentError, 'color requires background and text as strings for static colors'
        end

        meta_data[:color_background] = background
        meta_data[:color_text] = text_class
        meta_data[:color_border] = border_class if border_class
        meta_data[:hatch_fill] = hatch_fill unless hatch_fill.nil?
      end

      def apply_gradient_color(gradient, text, border, hatch_fill = nil)
        validate_gradient_options!(gradient, text, border)

        from = gradient[:from]
        to = gradient[:to]
        start = gradient[:start]
        stop = gradient[:stop]

        background_scale = normalize_color_scale({ from => start, to => stop })

        meta_data[:color_background_scale] = background_scale
        meta_data[:color_background] = stop
        meta_data[:color_text] = text
        meta_data[:color_border] = border if border
        meta_data[:hatch_fill] = hatch_fill unless hatch_fill.nil?
      end

      def gradient?(value)
        value.is_a?(Hash) && value[:type] == :gradient
      end

      def validate_no_options!(background, text_class, border_class, hatch_fill)
        return unless background || text_class || border_class || !hatch_fill.nil?

        raise ArgumentError, 'color does not accept other options with a block'
      end

      def validate_gradient_options!(gradient, text, border)
        validate_gradient_hash!(gradient)
        validate_gradient_text!(text)
        validate_gradient_border!(border)
        validate_gradient_keys!(gradient)
        validate_gradient_classes!(gradient)
      end

      def validate_gradient_hash!(gradient)
        return if gradient?(gradient)

        raise ArgumentError, 'color gradient must be provided via background: gradient(...)'
      end

      def validate_gradient_text!(text)
        return if text.is_a?(String)

        raise ArgumentError, 'color gradient requires text as a string'
      end

      def validate_gradient_border!(border)
        return if border.nil? || border.is_a?(String)

        raise ArgumentError, 'color gradient does not support border gradients'
      end

      def validate_gradient_keys!(gradient)
        values = gradient.values_at(:from, :to, :start, :stop)
        return if values.none?(&:nil?)

        raise ArgumentError, 'color gradient requires from, to, start, and stop'
      end

      def validate_gradient_classes!(gradient)
        start, stop = gradient.values_at(:start, :stop)
        return if start.is_a?(String) && stop.is_a?(String)

        raise ArgumentError, 'color gradient requires start and stop as strings'
      end
    end
  end
end
