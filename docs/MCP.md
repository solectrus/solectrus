# AI access (Model Context Protocol)

SOLECTRUS can expose its data to AI clients (such as Claude) through a
[Model Context Protocol](https://modelcontextprotocol.io) server, so you can ask
natural-language questions about your PV system ("Which day this year had the
highest solar production?", "How was my self-consumption last month?").

AI access (MCP) is a **sponsor-only feature** and is **disabled by default**.
Sponsors enable it under **Settings → General → AI access (MCP)**, where an
access token is generated and displayed. The endpoint is read-only and every
request must carry this token as `Authorization: Bearer <token>`. Without an
active sponsorship the endpoint is invisible (responds with 404).

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

Claude Desktop's remote-connector UI expects a publicly reachable, OAuth-capable
server, which a local self-hosted instance is not. For local use, bridge the
HTTP endpoint to stdio with [`mcp-remote`](https://www.npmjs.com/package/mcp-remote)
in `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "solectrus": {
      "command": "npx",
      "args": [
        "-y", "mcp-remote", "https://your-host/mcp",
        "--header", "Authorization:Bearer ${SOLECTRUS_MCP_TOKEN}",
        "--transport", "http-only"
      ],
      "env": { "SOLECTRUS_MCP_TOKEN": "your-token-from-the-settings" }
    }
  }
}
```

(Use `--allow-http` if you point it at a plain-HTTP URL.)
