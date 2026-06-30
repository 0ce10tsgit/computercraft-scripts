local MODEM_SIDE  = "top"
local PROTOCOL    = "vault_net"
local TIMEOUT     = 5
local DISPLAY_MIN = 1000

rednet.open(MODEM_SIDE)

-- Shared state (worker writes, GUI reads)
local state = {
    status   = "idle",
    sources  = 0,
    totals   = {},
    sorted   = {},
    last_run = nil,
}

local scroll = 0
local W, H   = term.getSize()
local PAGE   = H - 3

-- "[ Scan ]" button sits at the right end of line 1
local BTN_TEXT  = "[ Scan ]"
local BTN_COL   = W - #BTN_TEXT + 1  -- start column of button on line 1

local function rebuild_sorted()
    state.sorted = {}
    for name, count in pairs(state.totals) do
        if count > DISPLAY_MIN then
            state.sorted[#state.sorted + 1] = name
        end
    end
    table.sort(state.sorted, function(a, b) return state.totals[a] > state.totals[b] end)
end

-- ── GUI ───────────────────────────────────────────────────────────────────────

local function draw()
    local max_scroll = math.max(0, #state.sorted - PAGE)
    scroll = math.max(0, math.min(scroll, max_scroll))

    term.clear()

    -- Line 1: title + status + scan button
    term.setCursorPos(1, 1)
    term.write(string.format("Vault Excess  [%s]", state.status))
    term.setCursorPos(BTN_COL, 1)
    term.write(BTN_TEXT)

    -- Line 2: column headers + last run
    term.setCursorPos(1, 2)
    local time_str = state.last_run and ("last: " .. state.last_run) or "never scanned"
    print(string.format("  %-26s %8s   %s", "Item", "Total", time_str))

    -- Item rows
    for i = 1, PAGE do
        local name = state.sorted[scroll + i]
        if not name then break end
        print(string.format("  %-34s %8d", name:gsub("_", " "), state.totals[name]))
    end

    -- Scroll hint
    term.setCursorPos(1, H)
    if #state.sorted > PAGE then
        term.write(string.format("scroll %d-%d / %d",
            scroll + 1, math.min(scroll + PAGE, #state.sorted), #state.sorted))
    end
end

local function gui()
    while true do
        local ev, p1, p2, p3 = os.pullEvent()

        if ev == "mouse_click" and p3 == 1 and p2 >= BTN_COL then
            os.queueEvent("vault_scan")

        elseif ev == "mouse_scroll" then
            scroll = scroll + p1
            draw()

        elseif ev == "key" then
            if p1 == keys.up then
                scroll = scroll - 1
                draw()
            elseif p1 == keys.down then
                scroll = scroll + 1
                draw()
            end

        elseif ev == "vault_refresh" then
            draw()
        end
    end
end

-- ── Worker ────────────────────────────────────────────────────────────────────

local function worker()
    while true do
        os.pullEvent("vault_scan")

        state.status  = "querying..."
        state.sources = 0
        state.totals  = {}
        os.queueEvent("vault_refresh")

        rednet.broadcast({ cmd = "vault_highs" }, PROTOCOL)

        local timer = os.startTimer(TIMEOUT)
        while true do
            local ev, p1, p2, p3 = os.pullEvent()
            if ev == "rednet_message" and p3 == PROTOCOL then
                local msg = p2
                if type(msg) == "table" and msg.ok and type(msg.items) == "table" then
                    state.sources = state.sources + 1
                    for name, count in pairs(msg.items) do
                        state.totals[name] = (state.totals[name] or 0) + count
                    end
                    state.status = string.format("parsing %d response(s)...", state.sources)
                    rebuild_sorted()
                    os.queueEvent("vault_refresh")
                end
            elseif ev == "timer" and p1 == timer then
                break
            end
        end

        rebuild_sorted()
        state.last_run = textutils.formatTime(os.time(), true)
        state.status   = "idle"
        os.queueEvent("vault_refresh")
    end
end

-- ── Launch ────────────────────────────────────────────────────────────────────

draw()
parallel.waitForAll(gui, worker)
