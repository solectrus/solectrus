module Sensor
  module Definitions
    module Dsl # rubocop:disable Metrics/ModuleLength
      extend ActiveSupport::Concern

      META_DATA = Hash.new { |hash, key| hash[key] = {} }
      private_constant :META_DATA

      COLOR_DSL = Hash.new { |hash, key| hash[key] = Sensor::Definitions::Colors.new(META_DATA[key]) }
      private_constant :COLOR_DSL

      class_methods do # rubocop:disable Metrics/BlockLength
        def meta_data
          META_DATA[self]
        end

        def inherited_meta_data(key)
          ancestors.each do |ancestor|
            next unless ancestor.respond_to?(:meta_data)

            data = ancestor.meta_data
            return data[key] if data.key?(key)
          end

          nil
        end

        # Simple getters with nil default
        %i[unit value_range].each do |attr|
          define_method(attr) { meta_data[attr] }
        end

        # Boolean getters with false default
        %i[trendable more_is_better].each do |attr|
          define_method(attr) { meta_data.fetch(attr, false) }
        end

        # Trend aggregation getter with :sum default
        def trend_aggregation
          meta_data.fetch(:trend_aggregation, :sum)
        end

        def value(**options)
          handle_value_range(options)

          %i[unit category nameable].each do |attr|
            meta_data[attr] = options[attr] unless options[attr].nil?
          end
        end

        def color(background: nil, text: nil, border: nil, hatch_fill: nil, &)
          color_dsl.color(background:, text:, border:, hatch_fill:, &)
        end

        def gradient(from:, to:, start:, stop:)
          color_dsl.gradient(from:, to:, start:, stop:)
        end

        def icon(static_icon = nil, &)
          getter_or_setter(:icon, static_icon, &)
        end

        def permitted(value = nil, &)
          getter_or_setter(:permitted, value, default: true, &)
        end

        def calculate(&)
          return meta_data[:calculate_block] unless block_given?

          meta_data[:calculate_block] = proc(&)
          define_method(:calculate, &)
        end

        def chart(&block)
          raise ArgumentError, 'chart requires a block' unless block

          meta_data[:chart] = { block: }
        end

        def requires_permission(permission)
          meta_data[:permitted] = lambda do |*|
            ApplicationPolicy.instance.feature_enabled?(permission)
          end
        end

        def trend(more_is_better: false, aggregation: :sum)
          meta_data[:trendable] = true
          meta_data[:more_is_better] = more_is_better
          meta_data[:trend_aggregation] = aggregation
        end

        # Aggregations
        def aggregations(stored: nil, meta: nil, computed: nil, top10: false)
          meta_data[:summary_aggregations] = Array(stored) if stored
          meta_data[:summary_meta_aggregations] = Array(meta) if meta
          meta_data[:allowed_aggregations] = Array(computed) if computed
          meta_data[:top10_enabled] = top10
        end

        def top10_permitted(&block)
          raise ArgumentError, 'top10_permitted requires a block' unless block

          meta_data[:top10_permitted] = block
        end

        def summary_aggregations(*values)
          getter_or_setter_array(:summary_aggregations, values, default: [])
        end

        def allowed_aggregations(*values)
          if values.empty?
            return meta_data[:allowed_aggregations] || summary_aggregations
          end

          meta_data[:allowed_aggregations] = values.flatten
        end

        def summary_meta_aggregations(*values)
          if values.empty? && meta_data[:summary_meta_aggregations].present?
            return meta_data[:summary_meta_aggregations]
          end
          return values.flatten if values.any?

          calculated? ? [] : %i[sum avg min max]
        end

        def depends_on(*sensors, if: nil, &block)
          return resolved_dependencies if sensors.empty? && !block

          meta_data[:dependencies] = block || sensors.flatten
          meta_data[:dependency_condition] = binding.local_variable_get(:if)
        end

        def calculated?
          meta_data[:calculate_block].present?
        end

        private

        def color_dsl
          COLOR_DSL[self]
        end

        # Generic getter/setter for blocks or values
        def getter_or_setter(key, value = nil, default: nil, &)
          return meta_data.fetch(key, default) if value.nil? && !block_given?

          meta_data[key] = block_given? ? proc(&) : value
        end

        # Generic getter/setter for array values
        def getter_or_setter_array(key, values, default: [])
          return meta_data.fetch(key, default) if values.empty?

          meta_data[key] = values.flatten
        end

        # Resolve dependencies with conditional logic
        def resolved_dependencies
          deps = meta_data.fetch(:dependencies, [])
          cond = meta_data[:dependency_condition]
          return [] if deps.blank?
          return deps unless cond

          cond.call ? deps : []
        end

        def handle_value_range(options)
          range = options[:range]
          range = (0..100) if options[:unit] == :percent && range.nil?
          meta_data[:value_range] = range if range
        end
      end
    end
  end
end
