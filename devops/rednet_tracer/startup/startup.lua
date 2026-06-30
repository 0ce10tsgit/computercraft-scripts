local MODEM_SIDE = "top"
local MAX_COUNT  = 999
local W, H       = term.getSize()
local PAGE       = H - 2

rednet.open(MODEM_SIDE)

local entries   = {}  -- { sender, proto, count, summary }
local seen_keys = {}  -- serialized key -> index in entries
local scroll    = 0

local function summarize(sender, proto, msg)
    if proto == "pkg_log" and type(msg) == "table" then
        local label    = msg.label or ("id:" .. sender)
        local contents = type(msg.contents) == "table" and msg.contents or {}
        local parts    = {}
        for _, entry in ipairs(contents) do parts[#parts + 1] = entry end
        local payload  = #parts > 0 and table.concat(parts, ", ") or "empty"
        -- truncate to fit terminal width: "x999 pkg_log  label  " = ~22 chars overhead
        local max_payload = W - 22 - #label
        if #payload > max_payload then payload = payload:sub(1, max_payload - 1) .. "~" end
        return string.format("pkg_log  %s  %s", label, payload)
    elseif proto == "vault_net" and type(msg) == "table" then
        if msg.cmd then
            return string.format("vault_net  from %d  cmd=%s", sender, msg.cmd)
        elseif msg.ok ~= nil then
            local n = 0
            if type(msg.items) == "table" then
                for _ in pairs(msg.items) do n = n + 1 end
            end
            return string.format("vault_net  from %d  reply  %d types", sender, n)
        end
    end
    return string.format("%-10s from %d", tostring(proto), sender)
end

local function draw()
    local max_scroll = math.max(0, #entries - PAGE)
    scroll = math.max(0, math.min(scroll, max_scroll))

    term.clear()
    term.setCursorPos(1, 1)
    print(string.format("=== Rednet Tracer === %d unique", #entries))

    for i = 1, PAGE do
        local e = entries[scroll + i]
        if not e then break end
        local cnt = e.count >= MAX_COUNT and "x999" or string.format("x%-3d", e.count)
        print(string.format("%s %s", cnt, e.summary))
    end
end

draw()

while true do
    local ev, p1, p2, p3 = os.pullEvent()

    if ev == "rednet_message" then
        local sender, msg, proto = p1, p2, p3
        -- pkg_log uniqueness is per-sender only; contents vary per package
        local key = proto == "pkg_log"
            and string.format("%d|pkg_log", sender)
            or  string.format("%d|%s|%s", sender, tostring(proto), textutils.serialize(msg))

        if seen_keys[key] then
            local e = entries[seen_keys[key]]
            if e.count < MAX_COUNT then e.count = e.count + 1 end
            if proto == "pkg_log" then e.summary = summarize(sender, proto, msg) end
        else
            entries[#entries + 1] = {
                count   = 1,
                summary = summarize(sender, proto, msg),
            }
            seen_keys[key] = #entries
        end
        draw()

    elseif ev == "key" then
        if p1 == keys.up then
            scroll = scroll - 1
            draw()
        elseif p1 == keys.down then
            scroll = scroll + 1
            draw()
        end
    end
end
