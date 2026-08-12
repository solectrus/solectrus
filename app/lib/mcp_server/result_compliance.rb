module McpServer
  # Adds the members MCP revision 2026-07-28 requires in a result and the mcp
  # gem (1.1.0) omits, although it negotiates that revision. A client on it
  # validates against the published schema and rejects a result that misses
  # one, so each gap costs a whole response.
  #
  # Two rules, both from schema/2026-07-28:
  #
  #   - `resultType` is required in every result (SEP-2322). The gem never
  #     sets it. `complete` is the only value we can produce: every tool
  #     answers in one round trip and none asks the client for input.
  #   - `ttlMs` and `cacheScope` are required in a cacheable result
  #     (SEP-2549). The gem fills them wherever it applies its own cache
  #     metadata, which Server.build configures - every place but
  #     `server/discover`, where the gem states the omission itself ("The
  #     draft's `ttlMs`/`cacheScope` cache hints are not included here yet").
  #
  # Which result a response carries is read from the request's JSON-RPC
  # method, not guessed from the members present.
  #
  # https://modelcontextprotocol.io/specification/2026-07-28/basic#resulttype
  module ResultCompliance
    COMPLETE = 'complete'.freeze
    private_constant :COMPLETE

    # The cacheable results this server can produce, named as the spec names
    # them. `tools/list` is listed because the schema requires the hints
    # there, not because the gem misses them - it fills them, and an
    # already-filled result is left alone. We register no prompts and no
    # resources, so the remaining cacheable results of the schema cannot
    # occur.
    CACHEABLE_METHODS = %w[tools/list server/discover].freeze
    private_constant :CACHEABLE_METHODS

    # Takes the serialized JSON-RPC response and the method of the request it
    # answers, and returns the response with the required members set.
    # Anything that is not a result (an error response, the empty body of a
    # 202) passes through untouched, as does a member the server already set.
    def self.apply(json, method:)
      message = JSON.parse(json)
      result = message.is_a?(Hash) ? message['result'] : nil
      return json unless result.is_a?(Hash)

      message['result'] = complete(cacheable(result, method))
      JSON.generate(message)
    rescue JSON::ParserError
      json
    end

    def self.complete(result)
      return result if result.key?('resultType')

      { 'resultType' => COMPLETE }.merge(result)
    end
    private_class_method :complete

    def self.cacheable(result, method)
      return result if CACHEABLE_METHODS.exclude?(method)

      {
        'ttlMs' => Server::CACHE_TTL.in_milliseconds,
        'cacheScope' => Server::CACHE_SCOPE,
      }.merge(result)
    end
    private_class_method :cacheable
  end
end
