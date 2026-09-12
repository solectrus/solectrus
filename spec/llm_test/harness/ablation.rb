module LlmTest
  # One sentence taken OUT of the shipped tool list, so a run measures what it
  # was worth.
  #
  # The suite guards a description in one direction only: a case turns red when
  # a rule stops being carried, and `payload_size_spec` turns red when the
  # bytes grow. Nothing asks whether a sentence that cost 130 bytes still buys
  # anything, so prose can only accumulate - one such sentence was written,
  # measured at no effect over 11 runs, and taken out again by hand.
  #
  # An ablation does that without touching the server: the text is removed from
  # `initialize` and `tools/list` as they cross the bridge, the cases run, and
  # the baseline says what the model lost. Everything still green over enough
  # runs means the sentence has stopped earning its place.
  #
  # Not a substitute for thinking about the number of runs: a rule that holds
  # in 4 of 5 runs looks intact in three. Ablate with --runs 8 or more, on the
  # cases the text can possibly reach.
  class Ablation
    class Error < StandardError
    end

    # Resolves a Facts constant name ("TIMEFRAME_FORMS") or takes literal text.
    # A constant is the readable form and the one a note can cite later.
    def self.for(name)
      return if name.blank?

      new(name, text_for(name))
    end

    def self.text_for(name)
      return McpServer::Facts.const_get(name) if constant?(name)

      name
    end
    private_class_method :text_for

    def self.constant?(name)
      name.match?(/\A[A-Z][A-Z0-9_]*\z/) && McpServer::Facts.const_defined?(name, false)
    end
    private_class_method :constant?

    attr_reader :name, :text

    def initialize(name, text)
      @name = name
      @text = text
    end

    def apply(response) = response&.gsub(json_pattern, '')

    # What this ablation removes from one session, and from where. Refuses an
    # ablation that matches nothing: a run that removed no byte proves nothing
    # about the text, but reads exactly like one that proved it worthless.
    def report
      tools = occurrences_in(tool_list, json_pattern)
      instructions = occurrences_in(McpServer::Server.instructions, raw_pattern)
      total = tools + instructions

      raise Error, "#{name} does not occur in the shipped tool list - nothing to ablate." if total.zero?

      "Ablating #{name.truncate(60)}: #{text.bytesize} bytes x #{total} " \
        "(#{tools} in the tool definitions, #{instructions} in the instructions) " \
        "= #{text.bytesize * total} bytes removed per session"
    end

    private

    # How the words are separated in the haystack: by real whitespace in the
    # instructions, and by the two characters `\` and `n` inside a JSON string.
    SEPARATOR = '(?:\\\\n|\\s)+'.freeze
    private_constant :SEPARATOR

    # The text as it crosses the socket. Two things would otherwise make a gsub
    # match nothing and report the ablation as free:
    #
    # - The quotes the facts carry ("P30D", "2026-06-21") are escaped in JSON.
    # - A description is a heredoc, so its sentences are WRAPPED. Whoever
    #   ablates a paragraph copies it out of the source and gets line breaks
    #   and indentation that the shipped text does not have in the same places.
    #
    # So the words are matched one by one, with anything whitespace-like
    # between them. Which is also what makes the ablation independent of a
    # later re-wrap of the same sentence.
    def json_pattern
      @json_pattern ||= pattern_for { it.to_json[1..-2] }
    end

    def raw_pattern
      @raw_pattern ||= pattern_for { it }
    end

    def pattern_for(&)
      Regexp.new(text.split(/\s+/).map { Regexp.escape(yield(it)) }.join(SEPARATOR))
    end

    def occurrences_in(haystack, pattern) = haystack.scan(pattern).size

    def tool_list
      McpServer::Server
        .build
        .handle_json({ jsonrpc: '2.0', id: 1, method: 'tools/list', params: {} }.to_json)
        .to_s
    end
  end
end
