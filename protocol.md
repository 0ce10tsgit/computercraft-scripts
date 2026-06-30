# Rednet Protocols

---

## `pkg_log` — Farm Telemetry

**Direction:** Relay computers → Computer 0 (tracker dashboard)

Fired whenever a Create packager emits a `package_created` event. The relay reads the package contents and broadcasts immediately.

### Broadcast (relay → all)

```lua
rednet.broadcast({ label, dest, contents }, "pkg_log")
```

| Field      | Type            | Description                                      |
|------------|-----------------|--------------------------------------------------|
| `label`    | string          | Computer label (set via `os.setComputerLabel`), falls back to `"relay#<id>"` |
| `dest`     | string          | Package destination address, or `""` if none     |
| `contents` | array of string | Each entry is `"<count>x <item_name>"` e.g. `"32x iron_ingot"` |

Item names are already stripped of mod prefix (`:` and everything before it).

### Receiver (Computer 0 tracker)

Listens on modem side `"left"` with `os.pullEvent()` for `rednet_message` with protocol `"pkg_log"`. Parses each `contents` entry with pattern `^(%d+)x (.+)$`, accumulates totals in `items[name]`, tracks `first_seen[name]` timestamp for rate calculation.

---

## `vault_net` — Vault Stock Queries

**Direction:** Vault Lister (Computer 0) → Vault Trackers (Computers 4–6)

All messages are Lua tables. Both sides use modem side `"top"`.

### Commands (Lister → Trackers, broadcast)

```lua
rednet.broadcast({ cmd = "vault_highs" }, "vault_net")
```

| `cmd`         | Filter                              | Use case                    |
|---------------|-------------------------------------|-----------------------------|
| `"vault_highs"` | count **>** `CUTOFF` (strict)     | Find excess stock           |
| `"items"`       | count **>=** `CUTOFF` (inclusive) | Full manifest               |

`CUTOFF` is hardcoded to `5` in each tracker.

### Response (Tracker → Lister, unicast)

```lua
rednet.send(sender, { ok = true, items = { ... } }, "vault_net")
```

| Field   | Type    | Description                                          |
|---------|---------|------------------------------------------------------|
| `ok`    | boolean | Always `true` for a valid reply                      |
| `items` | table   | Map of `item_name → aggregated_count` across both vaults, pre-filtered by CUTOFF |

Item names are full registry names e.g. `"minecraft:iron_ingot"`.

### Lister behaviour

- Broadcasts `vault_highs`, then waits `TIMEOUT = 5` seconds for replies
- Aggregates all `items` maps by summing counts across trackers
- Only displays items where combined total **>** `DISPLAY_MIN = 1000`
- Scan is manual — triggered by clicking `[ Scan ]` button in the GUI

### Tracker behaviour

- Reads `left` and `right` peripherals (`create_connected:item_silo`) via `vault.list()`
- Sums counts across both vaults before filtering
- Responds directly to the sender with a single `rednet.send`

---

## Custom Events (internal, not rednet)

| Event           | Queued by | Consumed by | Meaning                        |
|-----------------|-----------|-------------|--------------------------------|
| `vault_refresh` | worker    | gui         | State changed, redraw the screen |
| `vault_scan`    | gui (click) | worker    | User clicked Scan, start a query cycle |
