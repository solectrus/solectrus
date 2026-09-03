module LlmTest
  # One case from llm_test/cases/*.yml, and the checks it makes against one run.
  #
  # A check either passes or names what went wrong. The failures are the report
  # - "called list_sensors although the sensor was known" says more about a
  # description than a pass rate does.
  class Case
    ATTRIBUTES = %w[
      id
      prompt
      expect_tools
      forbid_tools
      max_tool_calls
      expect_args
      expect_facts
      answer_must_match
      answer_must_not_match
      allow_tool_errors
      judge
      note
    ].freeze
    public_constant :ATTRIBUTES

    # How far a restated number may drift from the truth. The tools round by
    # unit, and a model converting Wh to kWh rounds again, so an exact match is
    # not the bar - naming the right quantity is.
    TOLERANCE = 0.03
    public_constant :TOLERANCE

    # A fact is stored in one unit, but naming it in the neighbouring one is
    # just as correct: 45.2 kWh and 45230 Wh are the same answer, and so are
    # 5400 W and 5.4 kW. Only the prefix is free - the quantity still has to
    # match.
    SCALES = [1, 1000, 0.001].freeze
    public_constant :SCALES

    def self.load_all(path)
      Dir[File.join(path, '*.yml')].flat_map do |file|
        YAML.safe_load_file(file).map { new(_1) }
      end
    end

    def initialize(attributes)
      unknown = attributes.keys - ATTRIBUTES
      raise ArgumentError, "unknown keys in case: #{unknown.join(', ')}" if unknown.any?

      @attributes = attributes
    end

    ATTRIBUTES.each do |name|
      define_method(name) { @attributes[name] }
    end

    # Everything that can be decided without asking a model. The judge runs
    # only on top of these, and only when the case defines a rubric.
    def check(result)
      failures = []
      failures << 'gave no answer (turn limit reached)' if result.truncated
      failures.concat(check_tools(result))
      failures.concat(check_arguments(result))
      failures.concat(check_facts(result))
      failures.concat(check_text(result))
      failures
    end

    # Every number in a text, in both the German and the English notation. The
    # separators are told apart by position, not by locale: the last one is the
    # decimal point when what follows it is one or two digits.
    def self.numbers_in(text)
      text.scan(/\d[\d.,]*\d|\d/).filter_map { |raw| parse_number(raw) }
    end

    def self.parse_number(raw)
      last = raw.rindex(/[.,]/)
      return raw.to_f unless last

      decimals = raw.length - last - 1
      if decimals.between?(1, 2)
        "#{raw[0...last].delete('.,')}.#{raw[(last + 1)..]}".to_f
      else
        raw.delete('.,').to_f
      end
    end

    private

    def check_tools(result) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      names = result.tool_names
      failures = []

      Array(expect_tools).each do |tool|
        failures << "did not call #{tool}" if names.exclude?(tool)
      end

      Array(forbid_tools).each do |tool|
        failures << "called #{tool}, which this question does not need" if names.include?(tool)
      end

      if max_tool_calls && names.size > max_tool_calls
        failures << "made #{names.size} tool calls, at most #{max_tool_calls} expected (#{names.join(', ')})"
      end

      unless allow_tool_errors
        result.tool_calls.select(&:error).each do |call|
          failures << "#{call.name}(#{call.arguments.to_json}) was rejected: #{call.error}"
        end
      end

      failures
    end

    def check_arguments(result)
      (expect_args || {}).filter_map do |tool, expected|
        call = result.tool_calls.find { _1.name == tool }
        next "did not call #{tool}" unless call

        actual = call.arguments.deep_stringify_keys
        mismatch = expected.reject { |key, value| matches?(actual[key], value) }
        next if mismatch.empty?

        "#{tool} was called with #{actual.to_json}, expected #{mismatch.to_json}"
      end
    end

    def matches?(actual, expected)
      case expected
      when Array
        wanted = expected.map { _1.to_s.downcase }
        (wanted - Array(actual).map { _1.to_s.downcase }).empty?
      else
        actual.to_s.casecmp?(expected.to_s)
      end
    end

    def check_facts(result)
      numbers = self.class.numbers_in(result.answer)

      Array(expect_facts).filter_map do |fact|
        truth = Dataset.facts.fetch(fact) # rubocop:disable Style/HashLookupMethod
        next if numbers.any? { |number| close?(number, truth) }

        # The answer itself, not the numbers parsed out of it: a run that fails
        # because the fixture is broken reads as "no data available", which the
        # bare number list hides.
        "the answer does not carry #{fact} (#{truth.round(1)}): #{excerpt(result.answer)}"
      end
    end

    def excerpt(answer)
      text = answer.to_s.squish
      text.length > 160 ? "#{text[0, 160]}..." : text
    end

    def close?(number, truth)
      SCALES.any? do |scale|
        scaled = truth * scale
        (number - scaled).abs <= [scaled.abs * TOLERANCE, 0.05].max
      end
    end

    def check_text(result)
      failures = []

      Array(answer_must_match).each do |pattern|
        failures << "the answer does not match /#{pattern}/" unless result.answer.match?(/#{pattern}/i)
      end

      Array(answer_must_not_match).each do |pattern|
        failures << "the answer matches /#{pattern}/, which it must not" if result.answer.match?(/#{pattern}/i)
      end

      failures
    end
  end
end
