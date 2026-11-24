module LlmTest
  # The records that a case of cases/writing.yml expects in the database after
  # its run (`expect_records`). Each entry finds its records by `find`, as a
  # `where` of its model, and states their `count` (one by default) and the
  # `attributes` of the first one. A number may drift by half a cent, because
  # a model rounds a price it reads.
  module RecordCheck
    module_function

    # The failures of all entries, empty when the database holds them
    def call(entries)
      ActiveRecord::Base.connection_pool.with_connection do
        entries.flat_map { check(_1) }
      end
    end

    def check(expected)
      model = expected['model'].constantize
      found = model.where(expected['find'].to_h { |name, value| [name, local(model, name, value)] })
      label = "#{model.name} #{expected['find'].to_json}"

      count = expected.fetch('count', 1)
      return ["found #{found.count} of #{label}, expected #{count}"] if found.count != count
      return [] if count.zero?

      record = found.first
      mismatch = expected.fetch('attributes', {}).reject { |name, value| same?(record.public_send(name), value) }
      return [] if mismatch.empty?

      actual = mismatch.keys.index_with { record.public_send(_1) }
      ["#{label} has #{actual.to_json}, expected #{mismatch.to_json}"]
    end

    # A time of `find` is a local time of the instance too. A `where` reads a
    # time as a text in UTC, so it gets the time of the instance first.
    def local(model, name, value)
      return value unless value.is_a?(String) && model.type_for_attribute(name).type == :datetime

      Time.zone.parse(value)
    end

    # A time of the case is a local time of the instance, like "2026-09-14
    # 10:55", so it compares as a time and not as a text
    def same?(actual, expected)
      case expected
      when nil then actual.nil?
      when Numeric then !actual.nil? && (actual.to_f - expected).abs < 0.005
      else
        return actual == Time.zone.parse(expected) if actual.is_a?(ActiveSupport::TimeWithZone)
        return actual == Date.parse(expected) if actual.is_a?(Date)

        actual.to_s.casecmp?(expected.to_s)
      end
    end
  end
end
