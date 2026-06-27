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

- `list_sensors` — discover available sensors, their units, aggregations and
  which tools each sensor supports (`supported_tools`)
- `get_system_info` — installation date, currency, timezone, installed peak
  power and which subsystems (battery, wallbox, heat pump, forecast) are
  configured
- `get_prices` — electricity tariff and feed-in compensation (time-dependent)
- `get_current_values` — current live readings, each with freshness metadata
  (`last_seen_at`, `age_seconds`)
- `get_totals` — aggregated **historical actual** values for a timeframe
- `get_ranking` — best/worst (or chronological) days/weeks/months for one or more sensors
- `get_series` — sub-daily time series (intraday curves) for one or more sensors
- `get_forecast` — forecast for the coming days: expected PV generation (energy
  still to come today and per upcoming day) plus the outdoor temperature
  (daily min/max/avg)

> **Units after aggregation.** Summing a power sensor (unit `watt`) yields an
> *energy*, so in `get_totals`/`get_ranking` the resulting `value` is in Wh,
> not W (divide by 1000 for kWh) — never read a watt-sum as a power.

The backend (InfluxDB for live/hourly data, PostgreSQL summaries for
day/month/year) is chosen automatically based on the requested timeframe.

### Actuals vs. forecast

`get_totals` is for **historical, measured** values only. Passing a forecast
sensor (e.g. `inverter_power_forecast`) returns a clear error rather than a
silent `null`, because the PostgreSQL summaries hold no forecast.

For the **forecast of the coming days**, use `get_forecast`. It returns the PV
generation as energy sums (Wh) and, when an outdoor temperature forecast is
configured, the daily temperature (°C):

```json
{
  "timezone": "Europe/Berlin",
  "generated_at": "2026-06-26T08:52:00+02:00",
  "generation": {
    "unit": "Wh",
    "today_remaining": 47250.0,
    "days": [
      { "date": "2026-06-27", "expected": 58800.0 },
      { "date": "2026-06-28", "expected": 58800.0 }
    ]
  },
  "temperature": {
    "unit": "°C",
    "days": [
      { "date": "2026-06-26", "min": 12.0, "max": 20.0, "avg": 16.8 },
      { "date": "2026-06-27", "min": 11.5, "max": 21.0, "avg": 17.2 }
    ]
  }
}
```

- `generation.today_remaining` is the energy still expected **after now** —
  already generated energy is excluded, so it never double-counts the current
  day. `generation.days` lists the full expected energy per upcoming day, as far
  as the forecast reaches (typically a few days); days too sparse to integrate
  are omitted.
- `temperature.days` gives daily min/max/avg for today and the upcoming days. It
  is omitted entirely when no outdoor temperature forecast is configured.

For the predicted power **curve** (intraday shape), use `get_series` on the
forecast sensor instead. To judge whether a whole month/year will be good,
combine `get_forecast` with `get_totals` for the measured part and earlier
years.

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

### Where does the client run? (cloud vs. local network)

This distinction decides whether a homelab install works, because the client —
not your browser — is what opens the connection:

- **claude.ai web and the Claude mobile apps** connect from **Anthropic's
  cloud**. They can only reach a **publicly resolvable HTTPS URL**. A
  private LAN address such as `http://192.168.1.42:3000/mcp` is
  invisible to them (wrong network, plain HTTP), so a homelab instance must
  first be exposed to the internet over HTTPS (see below).
- **Claude Desktop** runs **locally on your machine**, inside the
  same network as SOLECTRUS. It reaches a homelab URL directly — no public
  exposure needed, and plain HTTP is fine.
- **ChatGPT** (web *and* desktop) always connects from **OpenAI's cloud** — even
  the desktop app does not talk to a local server. So, like the claude.ai apps,
  it needs a publicly reachable HTTPS URL; a LAN-only instance is unreachable.

Which path fits you:

- **You already reach SOLECTRUS from outside over HTTPS** (reverse proxy,
  Cloudflare Tunnel, …) — the common setup if you check your PV system while
  away. Then the **claude.ai web app and the mobile apps just work**: add a
  custom connector with that `https://…/mcp` URL. This is the simplest option
  for most users.
- **Your instance is LAN-only** (e.g. `http://192.168.1.42:3000`, reachable only
  at home). Then either expose it over HTTPS first (see below) to use the
  claude.ai apps, or use **Claude Desktop**, which runs on your computer and
  talks to the LAN URL directly.

### claude.ai web and the Claude mobile apps

Add a **custom connector** and paste the URL above. You will be redirected to
SOLECTRUS once to enter your admin password.

This requires a **publicly reachable HTTPS URL**. If your instance only lives in
your homelab,
put a reverse proxy with a valid TLS certificate in front of it (Traefik, Caddy,
nginx + Let's Encrypt) or expose it without opening a port using a
[Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/),
then use that `https://…/mcp` URL.

### Claude Desktop

This bridges the HTTP endpoint via
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

**Plain HTTP (homelab):** if you point the client at a plain-HTTP LAN URL,
append `--allow-http`, e.g.:

```json
{
  "mcpServers": {
    "solectrus": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "http://192.168.1.42:3000/mcp",
        "--allow-http"
      ]
    }
  }
}
```

The OAuth callback then uses a local loopback URL
(`http://localhost:<port>/callback`), which the server accepts — so the whole
flow stays inside your network.

### ChatGPT

ChatGPT reaches MCP servers only from OpenAI's cloud (the desktop app included),
so it needs a **publicly reachable HTTPS URL** — there is no local-bridge or
plain-HTTP path like Claude Desktop's.

Custom MCP connectors live behind **Developer mode**, which you enable on the
web (chatgpt.com — not in the desktop app); it is available on the Plus, Pro,
Business, Enterprise and Edu plans:

1. chatgpt.com → **Settings → Apps & Connectors → Advanced settings** → turn on
   **Developer mode**.
2. **Connectors → Create**: give it a name, set the **MCP Server URL** to
   `https://your-host/mcp`, and choose Authentication **OAuth**.
3. Save → you are redirected to SOLECTRUS once to enter your admin password.

On Plus/Pro the connector is read-only — which is all SOLECTRUS exposes anyway.
Once added on the web it also appears in the ChatGPT desktop app.

## Troubleshooting

### Cloudflare blocks ChatGPT ("registration endpoint returned 403")

If SOLECTRUS sits behind Cloudflare — **including via Cloudflare Tunnel** —
Cloudflare's **Bot Fight Mode** can block ChatGPT during connection setup, with
this error:

```
Dynamic client registration failed: registration endpoint returned 403
```

Claude usually passes while ChatGPT does not, so *"Claude works but ChatGPT
doesn't"* is the typical signature.

The **free** Bot Fight Mode cannot be excepted per path, so either:

- turn **Bot Fight Mode off** (Security → Bots), or
- on Cloudflare **Pro**, use **Super Bot Fight Mode** and add a skip for the
  paths `/mcp`, `/oauth/*` and `/.well-known/oauth*`.
