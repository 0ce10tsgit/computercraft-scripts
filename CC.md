# CC:Tweaked + Create Mod — Peripheral Reference
> NeoForge 1.21.1 | Researched June 2026  
> Covers: CC:Tweaked core, Create native CC integration, CC:Bridge (ccbridge global), CC:C Bridge

---

## ⚠️ Important Caveats

- **CC:C Bridge for 1.21.1 is newly released** — it just updated from Create v5 to Create v6/1.21.1. The wiki on GitHub is still from the 1.19.2/1.20.1 era. Some APIs may have changed. Always verify in-game with the Lua REPL.
- **Create Item Vault uses `items()` not `list()`** — confirmed from real-world code. The standard CC `list()` may not work on vaults.
- **Create Connected Item Silo (`create_connected:item_silo`) uses standard `list()`** — confirmed in-game. Do NOT call `items()` on it; that method does not exist.
- **Always discover what's connected first** — run `peripheral.getNames()` and `peripheral.getType()` before assuming any peripheral name.

```lua
-- Discovery snippet — run this first on any new setup
for _, name in ipairs(peripheral.getNames()) do
    print(name, "->", peripheral.getType(name))
end
```

---

## 0. Hardware Reference

### Computer Types

| Type | Color | Mouse events | Recipe |
|---|---|---|---|
| Normal Computer | ❌ B&W only | ❌ | 7× stone |
| Advanced Computer | ✅ 16 colors | ✅ click/scroll/drag | 7× gold |
| Normal Pocket Computer | ❌ | ❌ | carried in inventory |
| Advanced Pocket Computer | ✅ | ✅ | gold version |
| Turtle | ❌/✅ | ❌ | computer + iron + chest |

For automation scripts (farm tracking, signal monitoring) a **normal computer** is sufficient. Advanced is only needed for color UIs or monitor touch input.

### Pocket Computer

Carried in your inventory, opens like an item. Has an **upgrade slot** for a wireless or ender modem — this is what allows it to send/receive rednet messages wirelessly with no physical modem block needed.

```lua
-- pocket computer with ender modem upgrade installed:
rednet.open("back")   -- "back" is the upgrade slot side
```

### Wired Modem

**Peripheral type returned by `getType()`:** `peripheral_hub`

Despite looking like a small block, CC:Tweaked calls it `peripheral_hub` internally. This is normal and expected — the peripheral name is what matters, not the type string.

- Right-click to activate (turns from grey to lit/red)
- **Both modems** (on computer AND on peripheral) must be right-clicked separately
- Place directly on a face of the target block (packager, vault, etc.)
- Networking cable connects to cable automatically — no modem needed at junctions

### Disk Drive

Block peripheral. Insert floppy disks to transfer files between computers. A floppy with `startup.lua` on it auto-runs on boot and **takes priority** over the computer's own startup file. Useful for bootstrapping blank computers.

```lua
local drive = peripheral.find("drive")
print(drive.getMountPath())   -- path where disk is mounted e.g. "/disk"
-- copy a file to disk:
fs.copy("myprogram.lua", "/disk/myprogram.lua")
```

### Printer

Prints text onto in-game paper/books. Novelty peripheral — not useful for automation. Requires ink (dye) and paper. Term-like API: `newPage()`, `write()`, `setCursorPos()`, `setPageTitle()`, `endPage()`.

### Speaker

Plays sounds or music. `speaker.playNote(instrument, volume, pitch)` or `speaker.playSound(soundName)`. Not relevant to automation but useful for alerts.

### Monitor

Place multiple monitor blocks adjacent to form a larger display. Same API as `term` but called on the peripheral. Advanced monitors support color and touch.

```lua
local mon = peripheral.find("monitor")
mon.setTextScale(0.5)     -- more characters per block (0.5 to 5 in 0.5 steps)
mon.getSize()             -- width, height of total monitor area
term.redirect(mon)        -- redirect all print() calls to monitor
term.restore()            -- restore to computer screen
```

Touch events (`monitor_touch`) only fire on **Advanced** monitors (gold).

---

## 0b. Networking Reference

### Two completely separate systems

| Modem type | Purpose | Exposes peripherals? | Range |
|---|---|---|---|
| **Wired modem** | Share peripherals over cable | ✅ Yes | Unlimited (cable) |
| **Wireless modem** | Computer↔computer messaging | ❌ No | 64 blocks |
| **Ender modem** | Computer↔computer messaging | ❌ No | Unlimited + cross-dimension |

These are NOT interchangeable. A wireless modem cannot expose a Packager. A wired modem cannot send rednet messages (without also opening it as a channel).

### Wired network setup

```
[Peripheral + wired modem] ──cable──┐
[Peripheral + wired modem] ──cable──┤──[Computer + wired modem]
[Peripheral + wired modem] ──cable──┘
```

- Only **one modem** needed on the computer to see the entire network
- Cable branches and T-junctions work freely — no modem at junctions
- Right-click **both** modems (computer side AND peripheral side) to activate
- All peripherals appear in `peripheral.getNames()` once connected

### Wireless / Ender modem setup

```lua
-- must open modem before using rednet
rednet.open("left")   -- whichever side the modem is on
rednet.open("back")   -- pocket computer upgrade slot

-- both ends must use the SAME modem type
-- ender modem ↔ ender modem  (unlimited range)
-- wireless ↔ wireless        (64 blocks, 384 at high altitude)
```

### Relay pattern (wired → ender → pocket)

One relay computer bridges a wired peripheral network to a wireless pocket computer:

```
[Packagers + wired modems] ──cable──[Relay: wired modem + ender modem]
                                              ↕ rednet
                                    [Pocket Computer + ender modem upgrade]
```

The relay has NO display and just runs a `startup.lua` that listens for events and broadcasts via rednet. The pocket computer receives anywhere in the base.

### modem.open() for wired networks

Even on a wired modem, you need to open a channel before peripheral events propagate:

```lua
local modem = peripheral.find("modem")
modem.open(1)   -- open channel 1 (any number works for peripheral events)
```

---

## 1. CC:Tweaked Core APIs

### 1.1 `peripheral` API

```lua
peripheral.getNames()                    -- list all connected peripheral names
peripheral.getType(name)                 -- get type string of a peripheral
peripheral.hasType(name, type)           -- check if peripheral is a given type
peripheral.find(type)                    -- find first peripheral of type
peripheral.find(type, filter_fn)         -- find with filter function
peripheral.wrap(name_or_side)            -- wrap a peripheral, returns method table
peripheral.call(name, method, ...)       -- call method on peripheral by name
peripheral.getName(wrapped)              -- get the network name of a wrapped peripheral
```

**Multiple types:** A block can have multiple types — e.g. a Create vault may be both `"create:item_vault"` and `"inventory"`. Check with `peripheral.getType()` which returns multiple values.

---

### 1.2 Generic `inventory` Peripheral

Works on any block that exposes a standard inventory (chests, barrels, hoppers, etc.).  
**Note: Create vaults use `items()` instead of `list()` — see Section 3.**

```lua
local inv = peripheral.find("minecraft:chest")

inv.size()                          -- number of slots
inv.list()                          -- { [slot] = {name, count, nbt?}, ... } — SPARSE, use pairs()
inv.getItemDetail(slot)             -- detailed info: displayName, name, count, maxCount, tags, damage...
inv.getItemLimit(slot)              -- max items this slot can hold
inv.pushItems(toName, fromSlot, limit?, toSlot?)   -- push FROM this inv TO another
inv.pullItems(fromName, fromSlot, limit?, toSlot?)  -- pull INTO this inv FROM another
```

**Item detail fields:**
```lua
{
    name        = "minecraft:iron_ingot",  -- internal ID
    displayName = "Iron Ingot",            -- human name
    count       = 32,
    maxCount    = 64,
    nbt         = "abc123...",             -- hash only, not full NBT
    tags        = { ["forge:ingots/iron"] = true, ... },
    damage      = 0,       -- if damageable
    maxDamage   = 250,     -- if damageable
}
```

**Key gotcha:** `list()` returns a **sparse** table. Empty slots are `nil`. Always use `pairs()`, never `ipairs()`.

```lua
-- Count specific item across all slots
local function countItem(inv, itemName)
    local total = 0
    for _, stack in pairs(inv.list()) do
        if stack.name == itemName then
            total = total + stack.count
        end
    end
    return total
end
```

**Transferring between inventories** (both must be on the same wired network):
```lua
local chest  = peripheral.find("minecraft:chest")
local barrel = peripheral.find("minecraft:barrel")

-- push slot 1 from chest into barrel (up to 32 items)
chest.pushItems(peripheral.getName(barrel), 1, 32)

-- pull slot 3 from barrel into chest
chest.pullItems(peripheral.getName(barrel), 3)
```

---

### 1.3 `redstone` API (built-in)

```lua
redstone.getInput(side)              -- boolean: is there redstone signal on this side?
redstone.setOutput(side, bool)       -- set redstone output on a side
redstone.getAnalogInput(side)        -- 0-15 signal strength input
redstone.getAnalogOutput(side)       -- 0-15 signal strength output
redstone.setAnalogOutput(side, val)  -- set analog output (0-15)
```

Sides: `"top"`, `"bottom"`, `"left"`, `"right"`, `"front"`, `"back"`

---

### 1.4 `os` API (selected useful functions)

```lua
os.getComputerID()           -- unique integer ID of this computer
os.getComputerLabel()        -- string label or nil
os.setComputerLabel(name)    -- set label
os.time()                    -- in-game time (0-24000 scale, not real time)
os.day()                     -- in-game day count
os.epoch("utc")              -- real-world milliseconds since epoch (best for seeding RNG)
os.pullEvent(filter?)        -- yield until event, returns event name + args
os.clock()                   -- CPU time used by this computer
os.reboot()                  -- reboot
os.shutdown()                -- shutdown
```

---

### 1.5 `term` API (selected)

```lua
term.getSize()               -- returns width, height (default: 51, 19)
term.clear()                 -- clear screen
term.clearLine()             -- clear current line
term.setCursorPos(x, y)      -- move cursor (1-indexed)
term.getCursorPos()          -- returns x, y
term.write(text)             -- write at cursor, no newline
term.setTextColor(color)     -- set fg color (requires advanced computer)
term.setBackgroundColor(col) -- set bg color (requires advanced computer)
term.isColor()               -- true if advanced computer
term.scroll(n)               -- scroll terminal n lines
```

**Color constants:** `colors.white`, `colors.orange`, `colors.magenta`, `colors.lightBlue`, `colors.yellow`, `colors.lime`, `colors.pink`, `colors.gray`, `colors.lightGray`, `colors.cyan`, `colors.purple`, `colors.blue`, `colors.brown`, `colors.green`, `colors.red`, `colors.black`

---

### 1.6 `fs` API (selected)

```lua
fs.exists(path)              -- boolean
fs.open(path, mode)          -- mode: "r", "w", "a", "rb", "wb"
fs.list(path)                -- list directory
fs.makeDir(path)
fs.delete(path)
fs.copy(from, to)
fs.move(from, to)
fs.getSize(path)
fs.getFreeSpace(path)
```

File read/write pattern:
```lua
local f = fs.open("myfile.txt", "w")
f.write("hello")
f.close()

local f = fs.open("myfile.txt", "r")
local content = f.readAll()
f.close()
```

---

### 1.7 `textutils` API (selected)

```lua
textutils.serialize(table)       -- table → string (Lua format)
textutils.unserialize(string)    -- string → table
textutils.serializeJSON(table)   -- table → JSON string
textutils.unserializeJSON(str)   -- JSON → table
textutils.formatTime(time, 24h)  -- format os.time() as clock string
textutils.slowPrint(text, rate)  -- print with typing effect
```

---

### 1.8 `rednet` API

Requires a modem to be opened first. Uses computer IDs as addresses.

```lua
rednet.open(side)            -- open modem on this side ("top", "back", etc.)
rednet.close(side)           -- close
rednet.send(id, message, protocol?)     -- send to specific computer ID
rednet.broadcast(message, protocol?)   -- send to all
rednet.receive(protocol?, timeout?)    -- block until message received
                             -- returns: senderID, message, protocol
rednet.isOpen(side?)         -- check if open
```

---

### 1.9 Events (via `os.pullEvent`)

```lua
local event, p1, p2, p3 = os.pullEvent()

-- Common events:
-- "key"              key, isHeld
-- "key_up"           key
-- "char"             character
-- "mouse_click"      button, x, y
-- "mouse_up"         button, x, y
-- "mouse_scroll"     direction, x, y
-- "monitor_touch"    side, x, y         (advanced monitor touch)
-- "monitor_resize"   side
-- "peripheral"       name               (peripheral connected)
-- "peripheral_detach" name              (peripheral disconnected)
-- "rednet_message"   senderID, msg, protocol
-- "redstone"         (any redstone change)
-- "timer"            timerID
-- "alarm"            alarmID
-- "terminate"        (Ctrl+T pressed)
```

Use `os.pullEvent("key")` to filter to only key events.  
Use `os.pullEventRaw()` to also catch `"terminate"` (prevents Ctrl+T from killing your program).

**Create logistics events** (fired by Create peripheral blocks when connected):
```lua
-- CONFIRMED signature for package_created (tested in-game):
-- local event, source, pkg = os.pullEvent("package_created")
-- event  = "package_created"
-- source = "Create_Packager_0"  ← which packager fired it (peripheral name)
-- pkg    = Package Object        ← has list(), getItemDetail(), getAddress() etc.

-- Other logistics events (signature unconfirmed, dump with textutils.serialize to verify):
-- "package_received"  (Packager/Frogport: package arrived)
-- "package_sent"      (Frogport: package sent onto conveyor)
-- "train_passing"     trainName string  (Train Observer: train entered range)
-- "train_passed"      trainName string  (Train Observer: train left range)
-- "train_arrival"     ...               (Train Network Monitor)
-- "train_departure"   ...               (Train Network Monitor)
```

**Debugging unknown event signatures** — dump exactly what an event returns:
```lua
-- wrap in parallel so it doesn't hang forever
parallel.waitForAny(
    function()
        local results = {os.pullEvent("package_created")}
        for i, v in ipairs(results) do
            print(i, type(v), tostring(v))
        end
    end,
    function() sleep(15) end
)
```

**Important:** `package_created` blocks the REPL if no package fires. Use `parallel` or a timeout when testing — see Section 1.12.

---

### 1.10 `monitor` Peripheral

Advanced monitors support touch and color. Same API as `term` but prefixed:

```lua
local mon = peripheral.find("monitor")

mon.setTextScale(scale)       -- 0.5 to 5 in 0.5 increments
mon.getSize()                 -- width, height (depends on monitor size + scale)
mon.clear()
mon.setCursorPos(x, y)
mon.write(text)
mon.setTextColor(color)
mon.setBackgroundColor(color)
mon.isColor()

-- Touch event fires as "monitor_touch": side, x, y
local _, side, x, y = os.pullEvent("monitor_touch")
```

**Redirecting term output to monitor:**
```lua
local mon = peripheral.find("monitor")
term.redirect(mon)   -- all future term.X calls go to monitor
-- ...
term.restore()       -- restore to computer screen
```

---

### 1.11 `settings` API

Persistent key-value store per computer. Survives reboots.

```lua
settings.set(key, value)     -- set a value
settings.get(key, default?)  -- get a value
settings.unset(key)          -- remove
settings.save(path?)         -- save to .settings (or custom path)
settings.load(path?)         -- load from .settings
settings.getNames()          -- list all set keys

-- Useful built-in settings:
settings.set("motd.enable", false)   -- disable MOTD
settings.save()
```

### 1.12 `parallel` API

Runs multiple functions concurrently as coroutines — essential for any program that needs to both listen for events AND do something else at the same time (e.g. live display while collecting data passively).

```lua
parallel.waitForAny(fn1, fn2, ...)   -- runs all, stops when ANY returns or errors
parallel.waitForAll(fn1, fn2, ...)   -- runs all, stops when ALL return
```

**Key behaviour:**
- Functions share the same Lua state — they can read/write shared tables
- Only one function runs at a time — they yield to each other on `sleep()` or `os.pullEvent()`
- If one function errors, `waitForAny` stops all; errors propagate up

**Live data collection + display pattern:**

```lua
local data = {}  -- shared between coroutines

local function collect()
    while true do
        local _, pkg = os.pullEvent("package_created")
        for _, item in pairs(pkg.list()) do
            data[item.name] = (data[item.name] or 0) + item.count
        end
    end
end

local function display()
    while true do
        term.clear()
        term.setCursorPos(1, 1)
        for item, count in pairs(data) do
            print(count .. "x " .. item)
        end
        sleep(1)  -- yield to collect() and refresh every second
    end
end

parallel.waitForAny(collect, display)
-- use waitForAll if both loops are infinite and you never want to stop
```

**Why `os.pullEvent` in REPL hangs:** `os.pullEvent` blocks the current coroutine until the event fires. In the REPL there's nothing else running, so the whole computer appears frozen. In a `parallel` setup this is fine — the other coroutine keeps running while one waits.

**Testing events without hanging:**

```lua
-- times out after 10 seconds if no event fires
parallel.waitForAny(
    function()
        print(textutils.serialize({os.pullEvent("package_created")}))
    end,
    function() sleep(10) end
)
```

---

### 1.13 Input, Shell & Deployment

```lua
read()                       -- block and read a line of user input, returns STRING
read(nil, history, complete) -- with tab completion (complete returns table of suffixes)
write(text)                  -- print without newline (no \n)
sleep(seconds)               -- yield for N seconds (minimum ~0.05 per tick)

shell.run(program, ...)      -- run a program by name
shell.execute(program, ...)  -- same but returns exit status boolean
```

**Multi-line paste limitation:** CC terminal only pastes the first line of clipboard. Solutions:
- `pastebin get <id> filename.lua` — paste code at pastebin.com, grab the ID
- SFTP directly into `world/computercraft/computer/<id>/` (see Section 9)
- `wget <raw_github_url> filename.lua` — pull from GitHub raw URL

**MOTD disable:**
```lua
settings.set("motd.enable", false)
settings.save()
-- runs immediately, persists across reboots
```

**Startup execution order:**
1. `startup.lua` (file in root) — runs on every boot
2. `startup/` (folder) — all `.lua` files inside run alphabetically in sequence
3. Disk startup takes **priority** over local if floppy has a `startup` file
4. MOTD and shell only appear AFTER startup scripts finish — an infinite loop prevents them entirely

---

### 1.14 Data Persistence (Rolling Log Pattern)

For storing persistent data like farm production logs with a cull to max entries:

```lua
local DATA_FILE = "production_log.json"
local MAX_ENTRIES = 60

local function load()
    if not fs.exists(DATA_FILE) then return {} end
    local f = fs.open(DATA_FILE, "r")
    local data = textutils.unserializeJSON(f.readAll())
    f.close()
    return data or {}
end

local function save(data)
    local f = fs.open(DATA_FILE, "w")
    f.write(textutils.serializeJSON(data))
    f.close()
end

local function addEntry(data, entry)
    table.insert(data, entry)
    while #data > MAX_ENTRIES do
        table.remove(data, 1)   -- cull oldest from front
    end
    save(data)
end

-- usage:
local log = load()
addEntry(log, {
    time  = os.time(),
    day   = os.day(),
    farm  = source,            -- from package_created event
    item  = item.name,
    count = item.count,
})
```

**Notes:**
- Use `textutils.serializeJSON` for portable JSON; `textutils.serialize` for Lua-format (not cross-compatible)
- Files may NOT be on disk until `os.reboot()` — SFTP via live server may show empty files until reboot
- `table.remove(t, 1)` shifts the whole table — fine for 60 entries, avoid for thousands

---

These come built into Create itself (no extra mods needed). Attach a wired modem to the block, right-click to connect, then wrap.

### 2.1 Speedometer

**Peripheral type:** `create:speedometer`

```lua
local speed = peripheral.find("create:speedometer")
speed.getSpeed()     -- returns RPM as number (can be negative for reverse)
```

---

### 2.2 Stressometer

**Peripheral type:** `create:stressometer`

```lua
local stress = peripheral.find("create:stressometer")
stress.getStress()           -- current stress load in SU
stress.getStressCapacity()   -- total capacity of the network in SU
```

---

### 2.3 Display Link

**Peripheral type:** `Create_DisplayLink`  
Allows writing text to Create's flip-dot displays, nixie tubes, signs, and lecterns.

```lua
local link = peripheral.find("Create_DisplayLink")
-- Exposes a subset of the term API
link.clear()
link.setCursorPos(x, y)
link.write(text)
link.getSize()          -- width, height of the linked display
```

---

### 2.4 Rotation Speed Controller

**Peripheral type:** varies — check in-game

```lua
local rsc = peripheral.wrap("create:rotation_speed_controller_0")
rsc.getTargetSpeed()         -- current target RPM setting
rsc.setTargetSpeed(rpm)      -- set target RPM
```

---

### 2.5 Sequenced Gearshift

```lua
local sg = peripheral.wrap("create:sequenced_gearshift_0")
sg.rotate(angle)             -- rotate by angle in degrees
sg.move(distance)            -- move a certain distance
```

**Note:** Using a computer to control a Sequenced Gearshift disables manual control. The GUI will grey out while a computer is connected.

---

### 2.6 Train Station (Create native)

```lua
local station = peripheral.wrap("create:station_0")
station.assemble()
station.disassemble()
station.getStationName()
station.getTrainName()
station.setStationName(name)
station.setTrainName(name)
station.getBogeys()          -- number of bogeys on present train
station.getPresentTrain()    -- boolean: is a train present?
station.clearSchedule()
```

---

## 3. Create Item Vault

**Peripheral type:** `create:item_vault`  
**Important:** Uses `items()` not `list()`. Confirmed from real-world usage.

```lua
local vault = peripheral.find("create:item_vault")
```

### 3.1 Reading items

```lua
-- Get all items (NOT list() — vault uses items())
local items = vault.items()

-- items() returns: { { name, displayName, count, ... }, ... }
-- NOT sparse — iterate with ipairs or pairs

for _, item in pairs(items) do
    print(item.name, item.count, item.displayName)
end
```

### 3.2 Count a specific item

```lua
local function countInVault(vault, itemName)
    local total = 0
    for _, item in pairs(vault.items()) do
        if item.name == itemName 
        or (item.displayName and item.displayName:lower() == itemName:lower()) then
            total = total + item.count
        end
    end
    return total
end

print(countInVault(vault, "minecraft:iron_ingot"))
```

### 3.3 Transferring items out of vault

```lua
-- Push specific slot FROM vault TO another inventory
vault.pushItem(peripheral.getName(output), slot, amount?)

-- The slot number comes from iterating items()
-- You must find which slot your item is in first
for slot, item in pairs(vault.items()) do
    if item.name == "minecraft:diamond" then
        vault.pushItem(peripheral.getName(output), slot, 32)
        break
    end
end
```

### 3.4 Transferring items into vault

```lua
-- Push FROM output container INTO vault
output.pushItems(peripheral.getName(vault), slot)
```

### 3.5 Vault structure notes

- Default: 20 slots per vault block
- Vaults connect to adjacent vaults to form multiblocks
- 1×1: up to 3 blocks long (60 slots max per row)
- 2×2: up to 6 blocks long
- 3×3: up to 9 blocks long (maximum 1620 total slots)
- Redstone Comparator output reflects fullness level

---

## 4. CC:Bridge (Create Computers) — Built-in `ccbridge` Global

**Mod:** CC:Bridge / Create Computers  
**No block required** — functions are injected directly into every CC:Tweaked computer as a global `ccbridge` table. The computer itself acts as a Redstone Link.

### 4.1 Check it's loaded

```lua
-- In the Lua REPL:
print(type(ccbridge))   -- should print "table"
                        -- if "nil", mod isn't loaded or isn't working

-- List available functions:
for k, v in pairs(ccbridge) do print(k, v) end
```

### 4.2 API

All functions have both a full name and a short alias.

```lua
-- READ a frequency pair
ccbridge.GetFrequency(freq1, freq2)
ccbridge.getf(freq1, freq2)
-- Returns: number 0-15 (signal strength), or 0 if nothing transmitting

-- SEND a signal for a duration
ccbridge.SendFrequency(freq1, freq2, active, duration)
ccbridge.sendf(freq1, freq2, active, duration)
-- active:   boolean — true to send signal, false to stop
-- duration: ticks — 0 or math.huge for indefinite; any positive number for timed

-- PULSE a signal repeatedly
ccbridge.PulseFrequency(freq1, freq2, active, pulses, ticksPerPulse)
ccbridge.pulsef(freq1, freq2, active, pulses, ticksPerPulse)
-- pulses:       number of pulses to fire
-- ticksPerPulse: duration of each pulse in ticks
```

**Frequency arguments:** item IDs as strings, e.g. `"minecraft:stone"`, `"minecraft:redstone_block"`. Use `""` for an empty slot.

### 4.3 Usage examples

```lua
-- Read a threshold gate signal
local signal = ccbridge.getf("minecraft:stone", "minecraft:redstone_block")
print("Signal:", signal)   -- 0-15

-- Send signal indefinitely (until explicitly stopped)
ccbridge.sendf("minecraft:iron_ingot", "minecraft:coal", true, math.huge)

-- Stop it
ccbridge.sendf("minecraft:iron_ingot", "minecraft:coal", false, 0)

-- Send for 3 seconds (60 ticks)
ccbridge.sendf("minecraft:diamond", "minecraft:redstone", true, 60)

-- Pulse 5 times, 10 ticks each
ccbridge.pulsef("minecraft:gold_ingot", "minecraft:lapis_lazuli", true, 5, 10)
```

### 4.4 Poll loop example

```lua
local FREQ1, FREQ2 = "minecraft:stone", "minecraft:redstone_block"
local THRESHOLD = 7

while true do
    local signal = ccbridge.getf(FREQ1, FREQ2)
    if signal >= THRESHOLD then
        print("Threshold met: " .. signal)
        -- trigger something
        ccbridge.sendf("minecraft:diamond", "minecraft:coal", true, 20)
    end
    sleep(1)
end
```

### 4.5 Notes

- The computer itself IS the Redstone Link — no bridge block needed
- Frequencies are the same item-pair system as Create's physical Redstone Links
- `sendf` with `duration = 0` turns the signal off
- `sendf` with `duration = math.huge` runs until the computer reboots or explicitly stopped
- Unlike a physical Redstone Link, this can read AND write any frequency from one computer

---

## 5. CC:C Bridge Peripherals

**Mod:** CC:C Bridge  
**Status for 1.21.1:** Updated to support Create v6 / 1.21.1 as of mid-2026. Wiki is still from 1.19.2 era — verify APIs in-game.

### 5.1 Source Block

A peripheral that mirrors the `term` API and writes to a linked Create display (Flip Display, Nixie Tube, Sign, Lectern).

**Peripheral type:** check in-game (likely `Create_SourceBlock` or similar)

```lua
local source = peripheral.find("Create_SourceBlock")  -- type may vary

-- Term-like API:
source.setCursorPos(x, y)
source.write(text)
source.scroll(yDiff)
source.clear()
source.clearLine()
source.getCursorPos()       -- returns x, y
source.getSize()            -- returns width, height

-- NOTE: color functions (setTextColor, setBackgroundColor) are ignored
-- NOTE: fires "monitor_resize" event when linked display changes size
```

### 5.2 Target Block

Reads information from adjacent Create machines.

```lua
local target = peripheral.find("Create_TargetBlock")  -- type may vary

-- Reading stress from adjacent Stressometer:
target.getStress()
target.getStressCapacity()

-- Reading speed from adjacent Speedometer:
target.getSpeed()
```

**Note:** The Target Block must be placed adjacent to the Create machine you want to read.

### 5.3 Scroller Pane

A physical HID block. Players scroll on it with their mouse wheel to set a value.

**Peripheral type:** check in-game

```lua
local scroller = peripheral.find("Create_ScrollerPane")  -- type may vary

scroller.getValue()          -- returns number -15 to 15
scroller.setValue(value)     -- set value programmatically (-15 to 15)
scroller.isLocked()          -- boolean
scroller.setLock(bool)       -- true = locked (players can't change), false = unlocked
```

**Note:** Fires `"scroller_changed"` event when player changes the value (does NOT fire when computer changes it).

### 5.4 RedRouter Block

A redstone router peripheral. Like the `redstone` API but for a specific block — allows long-distance redstone without the block adjacency requirement.

**Note:** CC:C Bridge docs say to prefer CC:Tweaked's built-in **Redstone Relay** block over RedRouter for new builds.

```lua
local router = peripheral.find("Create_RedRouter")  -- type may vary

router.setOutput(side, bool)         -- set side to on/off (strength 15/0)
router.setAnalogOutput(side, value)  -- set analog strength 0-15
router.getOutput(side)               -- get current output state
router.getInput(side)                -- get current input from world
router.getAnalogOutput(side)         -- get current analog output value
router.getAnalogInput(side)          -- get current analog input from world
-- toggleOutput(side) also exists
```

Sides: `"north"`, `"south"`, `"east"`, `"west"`, `"up"`, `"down"` (not the computer-relative ones)

### 5.5 Train Station (CC:C Bridge enhanced)

CC:C Bridge adds extra methods on top of Create's native train station peripheral.

```lua
local station = peripheral.find("Create_TrainStation")  -- type may vary

-- From Create native:
station.assemble()
station.disassemble()
station.getStationName()
station.getTrainName()
station.setStationName(name)
station.setTrainName(name)
station.getBogeys()
station.getPresentTrain()
station.clearSchedule()
```

---

## 6. Peripheral Discovery Cheat Sheet

Run these in the Lua REPL to figure out what you're working with:

```lua
-- List everything connected
for _, name in ipairs(peripheral.getNames()) do
    print(name, "->", peripheral.getType(name))
end

-- Dump all methods available on a peripheral
local p = peripheral.find("create:item_vault")
for k, v in pairs(p) do
    print(k, type(v))
end

-- Test both list() and items() on a vault
local v = peripheral.find("create:item_vault")
local ok1, r1 = pcall(function() return v.list() end)
local ok2, r2 = pcall(function() return v.items() end)
print("list() works:", ok1)
print("items() works:", ok2)

-- Inspect item structure
local items = v.items()
local first = items[1] or next(items)
if first then print(textutils.serialize(first)) end
```

---

## 7. Common Patterns

### Passive farm production tracking (parallel)

Collects `package_created` events from all packagers on the wired network while keeping the display live. Uses `parallel` so the computer isn't blocked waiting for events.

```lua
local totals = {}  -- { itemName = count }

local function collect()
    while true do
        -- CONFIRMED signature: event, source (peripheral name), pkg (Package Object)
        local _, source, pkg = os.pullEvent("package_created")
        for _, item in pairs(pkg.list()) do
            totals[item.name] = (totals[item.name] or 0) + item.count
        end
    end
end

local function display()
    while true do
        term.clear()
        term.setCursorPos(1, 1)
        print("=== Farm Production ===")
        for item, count in pairs(totals) do
            print(string.format("%-30s %d", item, count))
        end
        sleep(2)
    end
end

parallel.waitForAny(collect, display)
```

**Identifying which packager fired the event:** `source` (second return value) is the peripheral name e.g. `"Create_Packager_0"`. Map these to farm names in a lookup table:

```lua
local farmNames = {
    ["Create_Packager_0"] = "wheat_farm",
    ["Create_Packager_1"] = "iron_farm",
}
-- then: local farmName = farmNames[source] or source
```

### Relay pattern (wired → wireless)

One relay computer has both a wired modem (peripheral network) and ender modem (long range). Farm data flows from packagers → relay → pocket computer anywhere in base.

```lua
-- relay startup.lua
rednet.open("left")  -- ender modem side

local function collect()
    while true do
        local _, pkg = os.pullEvent("package_created")
        local items = {}
        for _, item in pairs(pkg.list()) do
            items[item.name] = (items[item.name] or 0) + item.count
        end
        rednet.broadcast(items, "farm_log")
    end
end

local function keepAlive()
    while true do sleep(60) end  -- prevents parallel from exiting
end

parallel.waitForAny(collect, keepAlive)
```

```lua
-- pocket computer
rednet.open("back")  -- ender modem upgrade side
local totals = {}

while true do
    local _, msg = rednet.receive("farm_log")
    for item, count in pairs(msg) do
        totals[item] = (totals[item] or 0) + count
    end
end
```



```lua
local FREQ1, FREQ2 = "minecraft:diamond", "minecraft:redstone"
local THRESHOLD = 7

while true do
    local signal = ccbridge.getf(FREQ1, FREQ2)
    if signal >= THRESHOLD then
        print("Threshold met: " .. signal)
    end
    sleep(1)
end
```

### Monitor vault stock and alert

```lua
local vault = peripheral.find("create:item_vault")
local ALERT_ITEM  = "minecraft:iron_ingot"
local ALERT_BELOW = 100

while true do
    local total = 0
    for _, item in pairs(vault.items()) do
        if item.name == ALERT_ITEM then
            total = total + item.count
        end
    end

    if total < ALERT_BELOW then
        ccbridge.sendf("minecraft:redstone", "minecraft:coal", true, math.huge)
        print("LOW STOCK: " .. total .. " " .. ALERT_ITEM)
    else
        ccbridge.sendf("minecraft:redstone", "minecraft:coal", false, 0)
    end

    sleep(5)
end
```

### Event-driven monitor touch UI

```lua
local mon = peripheral.find("monitor")
mon.setTextScale(1)

local function drawButton(mon, label, x, y, w, col)
    mon.setBackgroundColor(col)
    mon.setCursorPos(x, y)
    mon.write(string.rep(" ", w))
    mon.setCursorPos(x + math.floor((w - #label) / 2), y)
    mon.write(label)
    mon.setBackgroundColor(colors.black)
end

while true do
    local _, side, x, y = os.pullEvent("monitor_touch")
    -- handle touch at x, y
end
```

---

## 8. Known Quirks & Gotchas

| Issue | Detail |
|---|---|
| Vault uses `items()` not `list()` | Confirmed from real code. `list()` may return nil or error. |
| `list()` is sparse | Empty slots are nil — always use `pairs()`, never `ipairs()` |
| Wired modems need right-clicking | Both modems (on computer AND on peripheral) must be right-clicked to activate |
| `pushItems` needs wired network | Both inventories must be on the same cable network |
| `pushItem` vs `pushItems` | Vault uses `pushItem` (singular), standard inventories use `pushItems` |
| CC:C Bridge wiki is outdated | Wiki reflects 1.19.2 API. Peripheral type names may differ on 1.21.1 |
| Recursive menu = stack overflow | Don't call `menu()` from inside `menu()` — use a `while` loop instead |
| String from `read()` | Always `tonumber(read())` when you need arithmetic |
| Advanced computer required | `term.setTextColor()`, `term.setBackgroundColor()`, monitor touch all need advanced |
| `math.random` seeding | Seed with `math.randomseed(os.epoch("utc"))` for proper randomness |
| `os.pullEvent` hangs REPL | Blocks until event fires — wrap in `parallel` with a `sleep()` timeout when testing |
| `package_created` CONFIRMED signature | `event, source, pkg` — source is the peripheral name e.g. `"Create_Packager_0"`, NOT the package destination |
| `pkg.getAddress()` = destination | Returns where the package is going, not which packager sent it |
| Packager forgets `setAddress` | Address resets when no computer is attached — must call `setAddress` every boot in `startup.lua` |
| Wired network needs no modem per junction | Cable connects to cable automatically — modems only needed at computer and at each peripheral endpoint |
| Wireless vs ender modem | Both ends must match — ender modem on relay + ender modem upgrade on pocket computer |
| `peripheral_hub` is normal | Wired modems show as type `peripheral_hub` in `getType()` — expected, not an error |
| Files not flushed until reboot | CC:Tweaked may not write files to disk immediately — SFTP may show empty files; `os.reboot()` forces flush |
| Multi-line paste broken | CC terminal only pastes first line — use pastebin, wget, or SFTP instead |
| `read()` returns string | Always wrap in `tonumber()` before arithmetic — `"5" - 1` errors, `tonumber("5") - 1` works |
| modem.open() needed | Even on wired modems, call `modem.open(1)` before peripheral events propagate |

---

## 9. Development Workflow (VS Code + SFTP)

### Setup

CC computer files live on the server at:
```
world/computercraft/computer/<id>/
```

Where `<id>` is your computer's ID (`os.getComputerID()`).

**VS Code extension:** SFTP by Natizyskunk (`Natizyskunk.sftp`)

**Known bug (VS Code 1.123.0+):** `isDate is not a function` error breaks downloads. Fix by editing:
```
C:\Users\<you>\.vscode\extensions\natizyskunk.sftp-1.16.3\node_modules\ssh2\lib\protocol\SFTP.js
```
Line 10: change `const { inherits, isDate } = require('util');`  
To:
```js
const { inherits } = require('util');
const isDate = (d) => d instanceof Date;
```
Then restart VS Code.

### sftp.json for Pebble Hosting

```json
{
    "name": "Pebble",
    "host": "fl03.pebblehost.net",
    "protocol": "sftp",
    "port": 2222,
    "username": "your.email_XXXX",
    "password": "your-panel-password",
    "remotePath": "/world/computercraft/computer/0/",
    "uploadOnSave": true,
    "ignore": [".git", ".vscode", ".DS_Store"]
}
```

- **SFTP Details** are in Pebble panel → File Manager → SFTP Details button
- Port is **2222** (not 22)
- Username looks like `youremail@gmail.com.XXXX`
- Change `0` in `remotePath` to your actual computer ID

### Workflow

1. Edit `.lua` files in VS Code
2. `Ctrl+S` — auto-uploads to server (uploadOnSave)
3. In-game: `reboot` — computer picks up new files
4. To pull existing files from server: `Ctrl+Shift+P` → `SFTP: Sync Remote -> Local` (not Download Project — that has a bug with empty files)

### Keyboard shortcut to push

```json
// keybindings.json
{ "key": "ctrl+shift+u", "command": "sftp.sync.localToRemote" }
```