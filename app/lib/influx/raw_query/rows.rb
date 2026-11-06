class Influx
  class RawQuery
    # What a row of a raw query says beyond its value: the tags of its series,
    # and the type of its field. Influx::RawQuery extends it, so a caller reads
    # rows through the class that made them.
    module Rows
      # The columns of a row that are not a tag of its series
      COLUMNS = %w[result table _start _stop _time _value _field _measurement].freeze
      private_constant :COLUMNS

      def tags_of(row) = row.except(*COLUMNS).compact.sort.to_h

      def type_of(value)
        case value
        when Float then 'float'
        when Integer then 'integer'
        when true, false then 'boolean'
        else 'string'
        end
      end

      # { field => [type, ...] } of the rows. A field has more than one type
      # only where it was written with another type before.
      def types(rows)
        rows.group_by { it['_field'] }.transform_values { |field_rows| field_rows.map { type_of(it['_value']) }.uniq }
      end

      # [booleans, strings]: the fields that `function` cannot take as they
      # are. A field written both ways counts as a string, as only "last"
      # applies to it. None for "last" and "count", which take every type.
      def split(types, function)
        return [[], []] if %i[last count].include?(function)

        strings = types.select { |_, list| list.include?('string') }.keys
        booleans = types.select { |_, list| list.include?('boolean') }.keys - strings
        [booleans, strings]
      end
    end
  end
end
