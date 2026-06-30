package.path = package.path .. ";/res/?.lua"

rednet.open("left")

local items      = {}
local first_seen = {}
local sorted     = {}
local scroll     = 0

local W, H         = term.getSize()
local PAGE         = H - 4
local ACCURACY_MS  = 5 * 60 * 1000
local session_start = os.epoch("utc")

local function rebuild_sorted()
    sorted = {}
    for name in pairs(items) do sorted[#sorted + 1] = name end
    table.sort(sorted, function(a, b) return items[a] > items[b] end)
end

local function redraw()
    local now = os.epoch("utc")
    scroll = math.max(0, math.min(scroll, math.max(0, #sorted - PAGE)))

    local elapsed  = now - session_start
    local progress = math.min(elapsed / ACCURACY_MS, 1)
    local BAR_W    = 15
    local filled   = math.floor(progress * BAR_W)
    local bar      = "[" .. string.rep("#", filled) .. string.rep("-", BAR_W - filled) .. "]"
    local accuracy_label = progress >= 1
        and "rates stable"
        or ("~" .. math.ceil((ACCURACY_MS - elapsed) / 60000) .. "m to accuracy")

    local total_s    = math.floor(elapsed / 1000)
    local timer_str  = string.format("%dm %02ds", math.floor(total_s / 60), total_s % 60)

    term.clear()
    term.setCursorPos(1, 1)
    print("Base Telemetry" .. string.rep(" ", W - 14 - #timer_str) .. timer_str)
    print(string.format("%s %s", bar, accuracy_label))
    print(string.format("  %-26s %9s %8s", "Item", "Rate/min", "Total"))

    for i = 1, PAGE do
        local name = sorted[scroll + i]
        if not name then break end
        local elapsed_ms = now - first_seen[name]
        local rate_str = elapsed_ms < 60000
            and "  --"
            or string.format("%9.1f", items[name] / (elapsed_ms / 60000))
        print(string.format("  %-26s %9s %8d", name:gsub("_", " "), rate_str, items[name]))
    end

    term.setCursorPos(1, H)
    if #sorted > PAGE then
        term.write(string.format("scroll %d-%d / %d", scroll + 1, math.min(scroll + PAGE, #sorted), #sorted))
    end
end

while true do
    local ev, p1, p2, p3 = os.pullEvent()

    if ev == "rednet_message" and p3 == "pkg_log" then
        local msg = p2
        if type(msg) == "table" and msg.contents then
            local now = os.epoch("utc")
            for _, entry in ipairs(msg.contents) do
                local count, name = entry:match("^(%d+)x (.+)$")
                if name then
                    if not first_seen[name] then first_seen[name] = now end
                    items[name] = (items[name] or 0) + tonumber(count)
                end
            end
            rebuild_sorted()
            redraw()
        end

    elseif ev == "mouse_scroll" then
        scroll = scroll + p1
        redraw()

    elseif ev == "key" then
        if p1 == keys.up then
            scroll = scroll - 1
            redraw()
        elseif p1 == keys.down then
            scroll = scroll + 1
            redraw()
        end
    end
end
