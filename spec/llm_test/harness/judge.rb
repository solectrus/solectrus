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

    Verdict = Struct.new(:pass, :reason, :cost_usd, :model)
    public_constant :Verdict

    def initialize(model: DEFAULT_MODEL)
      @model = model
    end

    def call(test_case, result)
      answer = ClaudeCli.new(model: @model).call(prompt(test_case, result), system: SYSTEM)

      parse(answer.answer, answer.cost_usd).tap { _1.model = answer.model }
    end

    SYSTEM = <<~TEXT.strip
      You grade the answer of an assistant that queried a photovoltaic
      monitoring system. You are given the question, the tool calls it made and
      its answer, plus one criterion.

      Grade the criterion alone. Ignore style, length and language. An answer
      that is correct but phrased differently than the criterion still passes.
      You see the calls but not their results: take a fact the answer reports
      from them, like a date or a price, as given.

      First check the criterion in at most two sentences. Then end with one
      last line: "PASS" or "FAIL: <what is wrong, in one sentence>".
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

    # The verdict is the last line that starts with one. The judge reasons
    # first (see SYSTEM): asked for the verdict up front, it wrote "FAIL:" and
    # then argued in the same line that the criterion is met.
    def parse(text, cost_usd)
      # Markdown bold carries no verdict, like in "**FAIL:** reason"
      lines = text.to_s.strip.lines.map { _1.delete('*').strip }
      line = lines.rfind { _1.match?(/\A(PASS|FAIL)\b/) } || lines.first.to_s

      return Verdict.new(pass: true, cost_usd:) if line.start_with?('PASS')

      Verdict.new(pass: false, reason: line.sub(/\AFAIL:?\s*/, '').presence || 'no verdict', cost_usd:)
    end
  end
end
