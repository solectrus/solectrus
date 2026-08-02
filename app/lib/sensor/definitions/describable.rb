module Sensor
  module Definitions
    # Naming and description for sensors: the localized display name (with a
    # derived fallback for split/aggregate sensors) and the human-readable
    # description. Both are I18n-based so they stay bilingual. The systematic
    # variants (_grid/_pv/_total and the custom_* families) are composed from
    # translatable fragments instead of being listed one by one.
    module Describable
      # Suffix -> I18n leaf key for its label and source clause.
      SUFFIXES = { '_grid' => 'grid', '_pv' => 'pv', '_total' => 'total' }.freeze
      private_constant :SUFFIXES

      def display_name(format = :long)
        # 1. User-defined names have priority
        name_from_settings = Setting.sensor_names[name].presence
        return name_from_settings if name_from_settings

        # 2. I18n-based
        if %i[short long].exclude?(format)
          raise ArgumentError, "Unknown display name format: #{format}"
        end

        key = format == :short ? "sensors.#{name}_short" : "sensors.#{name}"
        fallback =
          format == :short ? I18n.t("sensors.#{name}", default: name.to_s) : name.to_s
        label = I18n.t(key, default: fallback)

        # 3. Derive a label instead of leaking the raw machine name
        # (e.g. "house_costs_grid" -> "House costs (Grid)").
        label == name.to_s ? derived_display_name(format) : label
      end

      # Human-readable description of what this sensor represents. Root sensors
      # are translated directly; systematic variants are derived.
      def description
        I18n.t("sensor_descriptions.#{name}", default: nil).presence ||
          derived_description
      end

      # Canonical label from I18n only, ignoring user-defined names; used to
      # compose the descriptions of derived sensors.
      def canonical_label
        I18n.t("sensors.#{name}", default: name.to_s.humanize)
      end

      # Whether the operator named this sensor themselves - directly, or
      # through the consumer a custom cost sensor borrows its label from
      # ("Waschmaschine" -> "Waschmaschine (Costs)"). It marks the display
      # names that cannot be derived from the sensor's name, which a caller
      # skipping display_name to save space still has to carry: nothing about
      # custom_power_01 reveals that it is the washing machine.
      def user_defined_name?
        return true if Setting.sensor_names[name].present?

        number = name.to_s[/\Acustom_(\d+)_costs(?:_(?:grid|pv))?\z/, 1]
        return false unless number

        Sensor::Registry.find(:"custom_power_#{number}")&.user_defined_name? || false
      end

      private

      # Label for a sensor without a localized name. Split sensors become
      # "<base> (Grid/PV/Total)"; custom-cost sensors borrow the consumer's
      # name ("Dishwasher (Costs)"); everything else humanizes the machine name.
      def derived_display_name(format)
        custom_cost_label(format) || split_label(format) ||
          name.to_s.humanize
      end

      def split_label(format)
        base, suffix = suffix_split
        return unless base

        "#{base.display_name(format)} (#{suffix_label(SUFFIXES[suffix])})"
      end

      # Custom-cost sensors have no name of their own, so reuse the matching
      # consumer's (user-defined) name and tag it as costs (and grid/pv).
      def custom_cost_label(format)
        case name.to_s
        when /\Acustom_(\d+)_costs\z/
          consumer_cost_label(Regexp.last_match(1), format)
        when /\Acustom_(\d+)_costs_(grid|pv)\z/
          consumer_cost_label(Regexp.last_match(1), format, Regexp.last_match(2))
        end
      end

      def consumer_cost_label(number, format, source = nil)
        consumer = Sensor::Registry.find(:"custom_power_#{number}")
        base = consumer ? consumer.display_name(format) : "custom_#{number}_costs".humanize

        tags = [suffix_label('costs')]
        tags << suffix_label(source) if source
        "#{base} (#{tags.join(', ')})"
      end

      def suffix_label(key)
        I18n.t("sensor_descriptions.suffix.#{key}")
      end

      def derived_description
        templated_description || suffix_description
      end

      # Descriptions for the templated/custom families, whose naming is too
      # irregular for the generic suffix logic.
      def templated_description
        case name.to_s
        when /\Ainverter_power_(\d+)\z/
          t_derived(:inverter_string, number: Regexp.last_match(1))
        when /\Acustom_power_(\d+)\z/
          t_derived(:custom_power, number: Regexp.last_match(1).to_i)
        when /\Acustom_power_(\d+)_(grid|pv)\z/
          split_description(:custom_power, Regexp.last_match(2), number: Regexp.last_match(1).to_i)
        when /\Acustom_power_total_(grid|pv)\z/
          split_description(:custom_power_total, Regexp.last_match(1))
        when /\Acustom_(\d+)_costs\z/
          t_derived(:custom_costs, number: Regexp.last_match(1).to_i)
        when /\Acustom_(\d+)_costs_(grid|pv)\z/
          split_description(:custom_costs, Regexp.last_match(2), number: Regexp.last_match(1).to_i)
        end
      end

      # Description for a regular base sensor split or aggregated by a known
      # suffix, reusing the base sensor's canonical label.
      def suffix_description
        base, suffix = suffix_split
        return unless base

        subject = %("#{base.canonical_label}")
        if suffix == '_total'
          t_derived(:total, subject:)
        else
          t_derived(:split, subject:, clause: source_clause(suffix.delete_prefix('_')))
        end
      end

      # Compose a split description from a named subject fragment and a source.
      def split_description(subject_key, source, **)
        t_derived(
          :split,
          subject: t_subject(subject_key, **),
          clause: source_clause(source),
        )
      end

      def source_clause(source)
        I18n.t("sensor_descriptions.derived.clause.#{source}")
      end

      def t_derived(key, **)
        I18n.t("sensor_descriptions.derived.#{key}", **)
      end

      def t_subject(key, **)
        I18n.t("sensor_descriptions.derived.subject.#{key}", **)
      end

      # Split "<base>_grid|_pv|_total" into [base_sensor, suffix] when the base
      # is itself a known sensor; otherwise nil.
      def suffix_split
        str = name.to_s
        SUFFIXES.each_key do |suffix|
          next unless str.end_with?(suffix)

          base = Sensor::Registry.find(str.delete_suffix(suffix).to_sym)
          return [base, suffix] if base
        end
        nil
      end
    end
  end
end
