module LlmTest
  # Grades what no regular expression can grade: whether the model read the
  # conventions correctly - a watt sum as energy, a partial period as partial,
  # a missing sensor as missing.
  #
  # It runs without tools and sees only the question, the calls and the answer,
  # never the case's own wording, so it grades the substance and not the
  # phrasing.
  class Judge
    # Haiku by default, like the runs it grades: the criteria are binary and
    # short, and a grader that costs more than the run it grades makes the
    # suite expensive for nothing. Raise it with --judge-model when a verdict
    # looks wrong.
    DEFAULT_MODEL = 'haiku'.freeze
    public_constant :DEFAULT_MODEL

    Verdict = Struct.new(:pass, :reason, :cost_usd)
    public_constant :Verdict

    def initialize(model: DEFAULT_MODEL)
      @model = model
    end

    def call(test_case, result)
      answer = ClaudeCli.new(model: @model).call(prompt(test_case, result), system: SYSTEM)

      parse(answer.answer, answer.cost_usd)
    end

    SYSTEM = <<~TEXT.strip
      You grade the answer of an assistant that queried a photovoltaic
      monitoring system. You are given the question, the tool calls it made and
      its answer, plus one criterion.

      Grade the criterion alone. Ignore style, length and language. An answer
      that is correct but phrased differently than the criterion still passes.

      Reply with one line: "PASS" or "FAIL: <what is wrong, in one sentence>".
    TEXT
    public_constant :SYSTEM

    private

    def prompt(test_case, result)
      <<~TEXT
        Question: #{test_case.prompt}

        Tool calls:
        #{result.tool_calls.map { "- #{_1.name}(#{_1.arguments.to_json})" }.join("\n")}

        Answer:
        #{result.answer}

        Criterion: #{test_case.judge}
      TEXT
    end

    def parse(text, cost_usd)
      line = text.to_s.strip.lines.first.to_s.strip

      return Verdict.new(pass: true, cost_usd:) if line.start_with?('PASS')

      Verdict.new(pass: false, reason: line.sub(/\AFAIL:?\s*/, '').presence || 'no verdict', cost_usd:)
    end
  end
end
