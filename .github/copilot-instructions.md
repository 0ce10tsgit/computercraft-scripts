# GitHub Copilot Instructions

## Project context
ComputerCraft (CC:Tweaked) scripts for a Minecraft base running NeoForge 1.21.1 with the Create mod. Code runs on in game computers with a Lua 5.2 runtime not standard like desaktop Lua.

## Workflow
- `devops/` is the signle source of truth. Scripts are deployed to in-game computers via SFTP (Posh-SSH).
- `devops/relay/relay.lua` are copied to relay computers (1, 2, 3…) as `startup/startup.lua`
- `devops/tracker/startup.lua` + `devops/tracker/res/` → are for the main computers(source and dependeenceis)
- Numbered folders (`0/`, `1/`, `2/`…) are git-ignored; they are SFTP-synced live copies, not source.

## CC:Tweaked specifics
- Terminal: 51×19 chars on a normal computer, 16 colours + mouse events on advanced.
- APIs to know: `rednet`, `term`, `os.pullEvent`, `os.epoch("utc")`, `peripheral`, `keys`, `colors`.
- `os.pullEvent()` filters terminate; `os.pullEventRaw()` catches it — use raw on relay computers to block Ctrl+T.
- `rednet.open(side)` must be called before any rednet use.
- `package.path = package.path .. ";/res/?.lua"` loads libs from the computer's `/res/` directory.
- No `io`, no `socket`, no coroutine-based parallelism beyond `parallel` API.

## Code style
- Plain Lua, no unnecessary abstractions.
- No comments unless the why is non-obvious.
- Prefer `local function` over anonymous assignments.
- Event loops use `os.pullEvent()` directly — avoid framework-managed loops unless PixelUI is in use.
- Pre-declare locals that closures need to reference forward (`local a, b, c` before any of them are assigned).

## Review priorities for long-running programs
These scripts run unattended for hours or days. Flag anything that causes a silent hang, crash, or data corruption over time:

- **Blocking calls in mixed-event loops** — using `rednet.receive` or `sleep` inside a loop that must also handle timers or input will starve those events. Use `os.pullEvent()` with explicit dispatch instead.
- **Unbounded table growth** — any table that appends indefinitely without a size cap or eviction policy is a memory leak. Enforce rolling windows or fixed-size buffers.
- **Unguarded peripheral calls** — any peripheral API call must be wrapped in `pcall`; peripherals can detach at any time and an unguarded call will crash the script permanently.
- **Peripheral or modem not present** — `rednet.open(side)` and `peripheral.wrap(side)` silently fail or error if nothing is attached. Validate that the peripheral exists before use and emit a clear error if not, rather than crashing mid-run.
- **Hardcoded peripheral sides** — if a modem or device side is hardcoded and the physical setup changes, the script breaks silently. Where possible, scan with `peripheral.find` or make the side configurable at the top of the file.
- **Changed computer labels or IDs** — code that keys data by `os.getComputerLabel()` will silently create a new entry if the label is renamed. If identity continuity matters, prefer `os.getComputerID()` which never changes.
- **Stale timer events** — always reassign the timer handle on each tick and match against it; old timer IDs from a previous cycle can fire and trigger logic out of turn.
- **Terminate exposure** — scripts meant to run permanently must use `os.pullEventRaw()` and explicitly swallow `terminate`. Plain `os.pullEvent()` will let Ctrl+T kill the process.
- **Unfiltered rednet listeners** — `rednet_message` without protocol filtering processes every broadcast on the network and risks corrupting state with unrelated traffic.
- **Forward-reference closures** — a Lua closure defined inside the RHS of its own `local x = …` cannot capture `x` (resolves as global nil). Pre-declare all locals that any callback references.

## Known integrations
- Create mod packagers fire `package_created` events; relay computers forward these over rednet with protocol `"pkg_log"`.
- PixelUI v2 (`require("pixelui")`): init with `PixelUI.create()`, attach widgets via `app.root:addChild(w)`, drive with `app:step(table.unpack(ev))` and `app:render()`.
