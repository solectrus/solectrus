module McpServer
  # The _grid/_pv suffix convention, in one place.
  #
  # A split does not measure a thing of its own: it divides a base sensor by
  # where the energy came from. list_sensors leaves them out of its index and
  # names their bases in `conventions.suffixes.split_bases` instead - three
  # steps that have to agree on what counts as a split.
  #
  # This is a NAMING rule only, and deliberately separate from what a split can
  # answer: that a split has no reading of a single instant follows from its
  # category (Sensor::Definitions::Base#instantaneous?), not from how it is
  # spelled.
  module SplitSensors
    module_function

    # _total is deliberately not among them: it aggregates a family rather than
    # dividing one sensor, and there are only a handful of them.
    SUFFIXES = %w[_grid _pv].freeze
    public_constant :SUFFIXES

    # [splits, rest] out of a list of sensor definitions.
    def partition(sensors)
      names = sensors.to_set(&:name)

      sensors.partition { split?(it.name, names) }
    end

    # Recognized by the base sensor actually being present, not by the name
    # ending in _grid/_pv alone - otherwise a sensor that merely happens to end
    # that way would silently vanish from every list, with nothing left naming
    # it.
    def split?(name, names)
      SUFFIXES.any? do |suffix|
        name.end_with?(suffix) && names.include?(:"#{name.to_s.delete_suffix(suffix)}")
      end
    end

    def base_name(name)
      suffix = SUFFIXES.find { name.end_with?(it) }

      name.to_s.delete_suffix(suffix.to_s)
    end
  end
end
