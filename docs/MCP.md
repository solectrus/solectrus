# AI access (Model Context Protocol)

SOLECTRUS can expose its data to AI clients (such as Claude) through a
[Model Context Protocol](https://modelcontextprotocol.io) server, so you can ask
natural-language questions about your PV system ("Which day this year had the
highest solar production?", "How was my self-consumption last month?").

AI access (MCP) is a **sponsor-only feature** and is **disabled by default**.
Sponsors enable it under **Settings → General → AI access (MCP)**. The endpoint
is read-only and protected by OAuth 2.1 (authorization code + PKCE); the only
credential is your existing **admin password** (`ADMIN_PASSWORD`). Without an
active sponsorship — or while the toggle is off — the endpoint and the whole
OAuth surface are invisible (respond with 404).

It is served at `POST /mcp` via stateless Streamable HTTP and offers these tools:

- `list_sensors` — discover available sensors, units and aggregations
- `get_system_info` — installation date, currency, timezone
- `get_prices` — electricity tariff and feed-in compensation (time-dependent)
- `get_current_values` — current live readings
- `get_totals` — aggregated values for a timeframe
- `get_ranking` — best/worst (or chronological) days/weeks/months for one or more sensors
- `get_series` — sub-daily time series (intraday curves) for one or more sensors

The backend (InfluxDB for live/hourly data, PostgreSQL summaries for
day/month/year) is chosen automatically based on the requested timeframe.

## Connecting a client

The server is an OAuth 2.1 authorization server, so most clients need nothing
but the URL. There is no token to copy and no client ID/secret to enter:
registration is dynamic and the client is public (PKCE-protected). On first
connect you are redirected to a SOLECTRUS page asking for your **admin
password**; after that the client holds a short-lived access token (refreshed
automatically).

The only value you ever enter is the MCP URL:

```
https://your-host/mcp
```

The server is provider-agnostic: any AI client works, not just Claude. Remote
clients use an HTTPS callback on their own domain (e.g.
`https://claude.ai/api/mcp/auth_callback`), native clients a loopback URL
(`http://localhost:<port>/callback`). Any HTTPS or loopback callback is
accepted; the target host is shown to you on the password page so you can
confirm where access is granted before entering your password.

### claude.ai web and the Claude mobile apps

Add a **custom connector** and paste the URL above. You will be redirected to
SOLECTRUS once to enter your admin password.

### Claude Desktop and Claude Code

These bridge the HTTP endpoint via
[`mcp-remote`](https://www.npmjs.com/package/mcp-remote), which performs the
OAuth flow (opening a browser for the password step) automatically:

```json
{
  "mcpServers": {
    "solectrus": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://your-host/mcp"]
    }
  }
}
```

(Append `--allow-http` if you point it at a plain-HTTP URL.) For Claude Code,
`claude mcp add --transport http solectrus https://your-host/mcp` works the
same way.
