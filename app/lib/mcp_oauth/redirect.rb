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

    SCHEMES = %w[http https].freeze
    private_constant :SCHEMES

    module_function

    # Provider-agnostic, so any AI client can connect: any http(s) URL with a
    # host and a path. Plain HTTP is accepted because a self-hosted client
    # rarely has TLS - a native client bridging over loopback, Open WebUI in a
    # container on the LAN, a second machine reached by name.
    #
    # What guards this is not the URL but the two steps around it. The consent
    # page names the host before the admin types the password, so a redirect to
    # a foreign host has to be waved through by hand. And the code is bound to
    # a PKCE challenge, so a code that reaches the wrong host cannot be
    # exchanged without the verifier that never left the client.
    #
    # A scheme rule would add nothing to that. It cannot stop phishing, which
    # only ever needs an HTTPS host we accept anyway, and it cannot tell a
    # local callback from a remote one: the browser resolves the host, this
    # server does not, and the two answers can differ.
    #
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
      SCHEMES.include?(uri.scheme) && uri.host.present? &&
        uri.path.present?
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

    # An http callback to a host that is not the admin's own machine. The code
    # then crosses the network in cleartext, so the consent page says so: only
    # the admin knows whether that network is theirs, and the server accepts
    # the callback either way.
    def plaintext?(redirect_uri)
      uri = URI.parse(redirect_uri)
      uri.scheme == 'http' && !loopback?(redirect_uri)
    rescue URI::InvalidURIError
      false
    end
  end
end
