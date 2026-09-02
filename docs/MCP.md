# AI access (Model Context Protocol)

SOLECTRUS can expose its data to AI clients (such as Claude) through a
[Model Context Protocol](https://modelcontextprotocol.io) server, so you can ask
natural-language questions about your PV system ("Which day this year had the
highest solar production?", "How was my self-consumption last month?").

AI access (MCP) is a **sponsor-only feature** and is **disabled by default**.
Sponsors enable it under **Settings → General → AI access (MCP)**. The endpoint
is read-only and protected by OAuth 2.1 (authorization code + PKCE); the only
credential is your existing **admin password** (`ADMIN_PASSWORD`), and the
authorization page accepts ten attempts per three minutes from one address —
enough for the one time you type it, not enough to guess it. Without an
active sponsorship — or while the toggle is off — the endpoint and the whole
OAuth surface are invisible (respond with 404).

It is served at `POST /mcp` via stateless Streamable HTTP and offers these tools.
`POST` is the only method that carries the protocol: the transport is stateless,
so there is no GET stream and no session to terminate, and `PUT`, `PATCH` and
`DELETE` answer `405` with `Allow: POST`. (A browser opening `/mcp` gets a short
setup guide instead, for the admin alone.)

- `list_sensors` — discover available sensors: a compact index of name,
  description and which tools work for each sensor (`tools`). A sensor no tool
  answers for is left out: the index exists to pick a sensor to call something
  with
- `get_sensor_details` — unit, display name, category and aggregations for a
  handful of named sensors, on the rare occasion the index is not enough
- `get_system_info` — installation date, currency, timezone, installed peak
  power, which subsystems (battery, wallbox, heat pump, forecast) are
  configured, and when data last arrived (the cheap "is the system still
  delivering?" check)
- `get_prices` — electricity tariff and feed-in compensation (time-dependent);
  per price type the value `effective` on the requested date, the change
  `history` up to that date, and any change scheduled after it under `upcoming`
- `get_current_values` — current live readings, each with freshness metadata
  (`last_seen_at` and `age_seconds`, on every entry — a reported value carries
  them as much as a null one)
- `get_totals` — aggregated **historical actual** values for a timeframe
- `get_periods` — `get_totals` grouped: one value per day/week/month/year, in
  date order and dense (a period without data comes back as `null`). The series
  behind a chart, and literally the query the web UI plots its bars from
- `get_ranking` — best/worst days/weeks/months for one or more sensors, ordered
  by value
- `get_series` — sub-daily time series (intraday curves) for one or more
  sensors, over a short window only (at most 99 hours). It reads the raw
  InfluxDB samples; anything from a week upwards is a `get_totals` or
  `get_periods` question, answered from the PostgreSQL summaries
- `get_forecast` — forecast for the coming days: expected PV generation (energy
  still to come today and per upcoming day) plus the outdoor temperature
  (daily min/max/avg)
- `get_amortization` — profitability of the whole system: whether and when the
  investment pays off (break-even, NPV, IRR), combining the measured savings
  with the manually kept cash flow register
- `get_cash_flows` — that register itself: the single investments, subsidies,
  costs and revenue with date, category, amount and note, filterable by
  category and date range

> **Units after aggregation.** Summing a power sensor (unit `watt`) yields an
> _energy_, so in `get_totals`, `get_periods` and `get_ranking` the `value` is in Wh,
> not W (divide by 1000 for kWh) — never read a watt-sum as a power. The same
> holds for `co2_reduction`: unaggregated — a live reading or a `get_series`
> curve — it is a rate (`gram_per_hour`, the CO₂ avoided at the current
> generation), aggregated an amount (`gram`).

The backend (InfluxDB for live/hourly data, PostgreSQL summaries for
day/month/year) is chosen automatically based on the requested timeframe.

Those summaries are built on demand, and a tool call that needs them builds
them first — just as opening the corresponding page does. The running day
matters most here: it has no summary until something asks for one, so without
this a question about today would be answered `null` while the inverter was
feeding in. A call builds at most a month of missing days; where more are
pending — an instance whose history was never opened in a browser — the answer
carries a `summary_note` saying how many days it is missing, and the summaries
page builds the rest with a progress bar.

### Curves and rankings are an axis plus values

`get_series`, `get_periods` and `get_ranking` return the axis once and then a
bare `values` list — not one dated object per entry:

```json
{
  "sensor": "inverter_power",
  "unit": "watt",
  "start": "2026-08-06T00:05:00+02:00",
  "step_seconds": 300,
  "point_count": 288,
  "values": [0.0, 0.0, 12.4, null, 210.7, "…"]
}
```

`values[i]` sits at `start` + i steps — one step being `step_seconds` for a
curve, one `period` for the two summary tools. Two optional fields qualify
that, and each is absent when it has nothing to say:

- `indices` gives the step offset of every value, for the cases where they are
  not consecutive: `include_nulls: false` in `get_series`, which drops the
  empty buckets, and `get_ranking`, which orders by size. Without it,
  `values[i]` is at offset i — always so in `get_periods`, whose list is dense
  by construction.
- `partial_at` **names the steps** the window covers only partly — both edges
  of a rolling window, the period still running. It names them the way `start`
  names its own: an ISO period start in a ranking (`"2026-06-01"`), a bucket
  end in a curve (`"2026-08-06T07:05:00+02:00"`). Never a position in `values`,
  which would be a second index space beside `indices` and disagree with it as
  soon as the two differ. Such a value is smaller for having been cut, not for
  having measured less, so never compare it with an unflagged one.

A `null` value means "no data", distinct from a measured `0`. `get_series`
states its axis even when `values` is empty — the timeframe and the resolution
fix the grid whether or not a bucket carried anything.

`step_seconds` counts **real** seconds. Add it to the instant `start` names and
convert to local time; do not carry the UTC offset in `start` forward as if it
were fixed. Bucket edges follow the installation's timezone, so across a
daylight-saving switch a calendar day holds 23 or 25 points rather than 24, and
the local hours skip or repeat one. Neither is a gap in the data.

The reason is context, not bandwidth. A point cost about 50 bytes, of which
~33 were an ISO timestamp that `start` and `step_seconds` already determine —
one sensor over one day at `5m` is 288 points, and it fell from 14.8 kB to
1.8 kB. A curve is the largest thing this server returns, and the client pays
for it in its context window.

### Split sensors (`_grid` / `_pv`)

A sensor ending in `_grid` or `_pv` does not measure anything of its own: the
Power Splitter service divides a base sensor by where the energy came from.
Both halves therefore report `calculated: true`.

**A split is an aggregate and nothing else.** The Power Splitter writes one
value per cycle of several minutes, so a split divides a _period_ and never
reads an instant. Pairing it with a base sensor sampled seconds ago mixes two
states of the system, and the difference can then exceed the whole. Every `_pv`
half declares a range of `0..`, so that mix no longer surfaces as an impossible
negative share — it surfaces as a plausible zero, which is the worse failure
and the reason the live reading is withheld rather than repaired.

The condition is that the window is **over**, not that it is long: once a day
has ended, every cycle inside it has been written and the division is as exact
as it is for a year.

So a split carries no `c` — `get_current_values` rejects it and leaves it out
of the default set. Ask for the **base sensor** for live power. It does carry
`s`, but `get_series` answers only over a timeframe that has **ended**, and
never finer than `5m`. Nothing lifts that floor in practice: the shortest
timeframe a split can be asked for is a whole day, and a day already costs `5m`
under the shared point budget. `get_totals` has no such condition, and
`get_periods`/`get_ranking` answer wherever the summaries store the split.

(The SOLECTRUS UI shows the split only from a week upwards. That is a rendering
limit, not a data one: the split is drawn as stacked bars, and shorter
timeframes render as line charts.)

`list_sensors` also omits the splits from its index — they lengthen it without
carrying anything their base sensor and the suffix do not.
`conventions.suffixes.split_bases` names every base that has them, and
`get_sensor_details` answers for a split by name.

### A `null` always means "no data"

`get_totals`, `get_periods` and `get_ranking` all read a per-period value, and
all reject a sensor that has none instead of answering `null`. That covers every sensor whose
`aggregations` are empty — a status text, a setpoint, a chart-only composite
such as `power_balance` — and, for `get_totals` alone, a forecast sensor, since
the summaries hold no forecast. (`get_ranking` does answer for one: it ranks
what was _predicted_ for each past period.) No argument would help in either
case, so the error says what the sensor is rather than what to pass — which is
what keeps a `null` value meaning "this timeframe holds no data" and nothing
else. The `t` and `r` letters in each sensor's `tools` mark the same sets, so
the call can be avoided rather than corrected.

Every rejection also says what to ask instead, and reads that off the same
matrix rather than naming a tool from memory — so it can never point at a tool
that rejects the sensor too, and it says plainly where nothing answers at all
(a chart-only composite carries an empty `tools`, which is also why
`list_sensors` leaves it out). Where
one sensor is rejected and another name was merely unknown, the error carries
both, so a typo does not cost a second round trip.

### Actuals vs. forecast

`get_totals` is for **historical, measured** values only.

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

Where no forecast has been stored at all — the provider is not set up, has not
been fetched yet, or is failing — `today_remaining` is `null` and a
`forecast_note` says so, next to an empty `days` list:

```json
{
  "timezone": "Europe/Berlin",
  "generated_at": "2026-06-26T08:52:00+02:00",
  "forecast_note": "No forecast data is stored, so this is NOT a forecast of zero: …",
  "generation": { "unit": "Wh", "today_remaining": null, "days": [] }
}
```

A `0` would be a number, and a number reads as a prediction. Report that case as
"no forecast available", never as "no generation expected".

For the predicted power **curve** (intraday shape), use `get_series` on the
forecast sensor instead. To judge whether a whole month/year will be good,
combine `get_forecast` with `get_totals` for the measured part and earlier
years.

### Profitability

For questions about whether the system pays off — break-even, payback,
NPV/IRR — use `get_amortization`. It combines the measured savings with the
manually kept cash flow register (investments, subsidies, operating costs,
revenue) and returns the amortization degree, the net position as of today,
the break-even date and the key financial figures. Two optional parameters
allow what-if scenarios: `period_years` (10–30, default 20) and `interest_rate`
(0–10 % p.a., default 3). Both are clamped into range rather than rejected, and
the response echoes what was applied. The lower bound of `period_years` grows
with the age of the system: a period that has already ended says nothing about
the investment, so a system running for 12 years cannot be evaluated over 10.
If no cash flows are configured yet, the tool reports that there is nothing to
amortize.

The figures aggregate the register, so a question about a single entry ("what
did the battery cost?", "which repairs were there?") is answered by
`get_cash_flows` instead. It returns the entries themselves — date, category,
amount and the note that was typed with them — optionally narrowed by
`categories` and by a `from`/`to` date range, `desc` by date and capped at
`limit` (default 50, at most 200). `total_count`, `sum` and `sum_by_category`
always cover every matching entry, so a limited list still adds up to the
totals above it. The category, not the sign of the amount, decides how an entry
counts: `investment`/`subsidy`/`refund` shape the investment base,
`compensation`/`manual_savings`/`operating_cost`/`repair` the operating cash
flow, and `other` counts nowhere.

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
clients use an HTTPS callback on their own domain (for example
`https://claude.ai/api/mcp/auth_callback`), native clients a loopback URL
(`http://localhost:<port>/callback`), and a client on your own network its
own address or name (`http://192.168.1.98:8080/callback`,
`http://openwebui.fritz.box/callback`). Any http(s) callback is accepted,
because a self-hosted client on your network rarely has TLS.

Two steps guard this, and neither is the URL. The password page names the
callback host, so you see where access goes before you type your password.
And the code is bound to a PKCE challenge that stays inside the client, so a
code that reaches the wrong host cannot be exchanged for a token.

### Ending access

One authorization lasts **90 days**, however often the client refreshes in
between. After that the client asks for the admin password again. There are two
ways to end it sooner, and both drop **every** connected client at once:

- **Change `ADMIN_PASSWORD`.** It is the only credential this flow checks, so
  changing it invalidates every access and refresh token ever issued.
- **Switch AI access off** under Settings → General. This rotates the OAuth
  signing secret, so switching it back on does not bring old connections back.

There is no per-client revocation: tokens are stateless and nothing is stored
server-side, which is also why no client list exists to revoke from.

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
- **ChatGPT** (web _and_ desktop) always connects from **OpenAI's cloud** — even
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

Claude usually passes while ChatGPT does not, so _"Claude works but ChatGPT
doesn't"_ is the typical signature.

The **free** Bot Fight Mode cannot be excepted per path, so either:

- turn **Bot Fight Mode off** (Security → Bots), or
- on Cloudflare **Pro**, use **Super Bot Fight Mode** and add a skip for the
  paths `/mcp`, `/oauth/*` and `/.well-known/oauth*`.
