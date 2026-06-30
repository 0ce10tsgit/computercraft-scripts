local MODEM_SIDE  = "top"
local REQ_SIDE    = "back"
local PROTOCOL    = "vault_net"
local TIMEOUT     = 5
local THRESHOLD   = 10000
local OVERSHOOT   = 500   -- always dumps this many extra past threshold  -- trigger above this
local DUMP_TARGET = 0      -- dump down to this (below THRESHOLD guarantees overshoot)
local CHECK_EVERY = 300
local DOUBLE_P_MS = 500     
local TARGETS     = { "create:cinder_flour", "minecraft:bread" }

local TITLE = "=== Garbage Man ==="

local state = {
    last_check = nil,
    counts     = {},
    last_dump  = nil,
}

local W         = term.getSize()
local last_p_at = 0

-- ── UI ───────────────────────────────────────────────────────────────────────
local function draw()
    term.clear()
    term.setCursorPos(1, 1)
    term.write(TITLE)

    term.setCursorPos(1, 2)
    print(string.rep("-", W))
    print(string.format("Last check: %s", state.last_check or "never"))
    for _, name in ipairs(TARGETS) do
        local short = name:match(":(.+)") or name
        local count = state.counts[name] or 0
        local flag  = count > THRESHOLD and "  DUMPING" or "  in check"
        print(string.format("  %-22s %6d%s", short, count, flag))
    end
    print(string.format("Last dump:  %s", state.last_dump or "never"))
    print(string.rep("-", W))
    print("double tap p to manual scan")
end

-- ── Network ───────────────────────────────────────────────────────────────────

local function query_totals()
    rednet.broadcast({ cmd = "vault_highs" }, PROTOCOL)
    local totals = {}
    local t      = os.startTimer(TIMEOUT)
    local anim_t = os.startTimer(0.4)
    local dot    = 0

    local function tick()
        dot = (dot % 3) + 1
        term.setCursorPos(#TITLE + 2, 1)
        term.write("fetching" .. string.rep(".", dot) .. string.rep(" ", 3 - dot))
    end
    tick()

    while true do
        local ev, p1, p2, p3 = os.pullEvent()
        if ev == "rednet_message" and p3 == PROTOCOL then
            local msg = p2
            if type(msg) == "table" and msg.ok and type(msg.items) == "table" then
                for name, count in pairs(msg.items) do
                    totals[name] = (totals[name] or 0) + count
                end
                tick()
            end
        elseif ev == "timer" and p1 == anim_t then
            tick()
            anim_t = os.startTimer(0.4)
        elseif ev == "timer" and p1 == t then
            break
        elseif ev == "timer" then
            os.queueEvent("timer", p1)
        end
    end

    return totals
end

-- ── Dump ──────────────────────────────────────────────────────────────────────

-- setRequest accepts up to 9 slots, each capped at 256. Batch multiple calls
-- to cover larger amounts.
local function dump_item(req, item_name, amount)
    local remaining = amount
    while remaining > 0 do
        local slots = {}
        for _ = 1, 9 do
            if remaining <= 0 then break end
            local per_slot = math.min(remaining, 256)
            slots[#slots + 1] = { name = item_name, count = per_slot }
            remaining = remaining - per_slot
        end
        req.setRequest(table.unpack(slots))
        req.request()
    end
end

-- ── Check cycle ───────────────────────────────────────────────────────────────

local function check()
    draw()
    local totals     = query_totals()
    local needs_dump = false

    state.last_check = textutils.formatTime(os.time(), true)
    for _, name in ipairs(TARGETS) do
        state.counts[name] = totals[name] or 0
        if state.counts[name] > THRESHOLD then needs_dump = true end
    end

    if needs_dump then
        local req = peripheral.wrap(REQ_SIDE)
        if req then
            req.setAddress("!!TRASH!!")
            for _, name in ipairs(TARGETS) do
                local excess = state.counts[name] - THRESHOLD + OVERSHOOT
                if excess > 0 then
                    dump_item(req, name, excess)
                end
            end
            state.last_dump = textutils.formatTime(os.time(), true)
        end
    end

    draw()
end

-- ── Main ──────────────────────────────────────────────────────────────────────

rednet.open(MODEM_SIDE)
check()

local check_timer = os.startTimer(CHECK_EVERY)
while true do
    local ev, p1 = os.pullEvent()

    if ev == "timer" and p1 == check_timer then
        check()
        check_timer = os.startTimer(CHECK_EVERY)

    elseif ev == "key" and p1 == keys.p then
        local now = os.epoch("utc")
        if now - last_p_at <= DOUBLE_P_MS then
            last_p_at = 0
            check()
            check_timer = os.startTimer(CHECK_EVERY)
        else
            last_p_at = now
        end
    end
end
