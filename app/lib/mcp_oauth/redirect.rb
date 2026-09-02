module McpOauth
  # Everything this server can say about a callback URL the client asked for.
  #
  # The URL is the one piece of the flow an attacker chooses freely, and the
  # consent page is what stands between it and the admin's password. So the
  # questions here are all the same question: what will the admin be told, and
  # is it true?
  #
  # Split from McpOauth for the same reason Urls is: this decides nothing about
  # tokens and touches no secret. It parses a string and answers about it.
  module Redirect
    # Loopback hosts for native clients (Claude Desktop, Claude Code, and any
    # other AI client bridging via a local callback). Per RFC 8252 the port is
    # dynamic and MUST be ignored when matching; the path is client-specific
    # (mcp-remote uses /oauth/callback, others /callback) and is not pinned - a
    # loopback redirect can only be intercepted by a process on the local
    # machine.
    LOOPBACK_HOSTS = %w[localhost 127.0.0.1 ::1].freeze
    private_constant :LOOPBACK_HOSTS

    module_function

    # Provider-agnostic, so any AI client can connect: accept any HTTPS callback
    # (the target host is shown to the admin on the authorization page, so the
    # consent step - not a hardcoded allowlist - is what guards against a
    # phishing redirect to a foreign host) plus loopback HTTP for native
    # clients. Plain HTTP to non-loopback hosts is rejected (it would leak the
    # code in cleartext to a remote host).
    # A host is required, because the whole guard is that the admin sees one.
    # "https:/evil.com/cb" carries none: URI.parse reads it as path
    # "/evil.com/cb", so the consent page shows an empty host, and the browser
    # resolves the Location we send against the request URL - which invents the
    # host back out of the path whenever the two schemes differ, as they do on
    # a plain-http instance (docs/MCP.md offers one). The code then reaches a
    # host that was never named.
    def valid?(redirect_uri)
      return false if redirect_uri.blank?

      uri = URI.parse(redirect_uri)
      uri.host.present? && uri.path.present? &&
        (uri.scheme == 'https' || loopback?(redirect_uri))
    rescue URI::InvalidURIError
      false
    end

    # A native client's loopback callback (http://localhost etc.)? Such a
    # redirect can only be received by a process on the admin's own machine, so
    # the consent page describes it as a local client instead of showing the
    # uninformative host "localhost".
    def loopback?(redirect_uri)
      uri = URI.parse(redirect_uri.to_s)
      # #hostname (not #host) strips IPv6 brackets: "[::1]" -> "::1".
      uri.scheme == 'http' && LOOPBACK_HOSTS.include?(uri.hostname)
    rescue URI::InvalidURIError
      false
    end
  end
end
