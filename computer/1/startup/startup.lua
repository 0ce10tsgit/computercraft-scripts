-- startup.lua — farm relay computer
-- Packager directly on back. Wired modem on top to computer 0.
-- Set name once with: os.setComputerLabel("farm_name") then reboot.

rednet.open("top")

local W, H   = term.getSize()
local WARN_H = 12
local LOG_H  = H - WARN_H
local label  = os.getComputerLabel() or ("relay#" .. os.getComputerID())

local function row(text)
    local inner = W - 4
    return "# " .. text .. string.rep(" ", math.max(0, inner - #text)) .. " #"
end

local WARNING = {
    string.rep("#", W),
    row(""),
    row("/!\\  /!\\  /!\\  DO NOT INTERRUPT  /!\\  /!\\  /!\\"),
    row(""),
    row("RELAY: " .. label),
    row(""),
    row("Forwards farm package data to computer 0."),
    row("Closing this will cause DATA LOSS."),
    row(""),
    row("Ctrl+T is BLOCKED to protect this relay."),
    row("Press Q to stop relay for maintenance."),
    string.rep("#", W),
}

term.clear()
for i, line in ipairs(WARNING) do
    term.setCursorPos(1, i)
    term.write(line:sub(1, W))
end

local logBuf = {}

local function addLog(text)
    table.insert(logBuf, text)
    if #logBuf > LOG_H then table.remove(logBuf, 1) end
    for i = 1, LOG_H do
        term.setCursorPos(1, WARN_H + i)
        term.clearLine()
        if logBuf[i] then term.write(logBuf[i]:sub(1, W)) end
    end
end

addLog("  relay started")

-- pullEventRaw lets us catch and swallow terminate (Ctrl+T).
-- Args differ per event type, so capture as table.
while true do
    local ev = { os.pullEventRaw() }

    if ev[1] == "terminate" then
        addLog("  !! Ctrl+T blocked - press Q to stop for maintenance !!")

    elseif ev[1] == "key" and ev[2] == keys.q then
        term.clear()
        term.setCursorPos(1, 1)
        print("[ " .. label .. " ] relay stopped for maintenance.")
        print("Run 'startup' or reboot to restart.")
        break

    elseif ev[1] == "package_created" then
        local pkg = ev[3]
        local parts = {}
        local ok, items = pcall(function() return pkg.list() end)
        if ok and items then
            for _, item in pairs(items) do
                local name = (item.name or "?"):match(":(.+)") or item.name
                parts[#parts + 1] = item.count .. "x " .. name
            end
        end

        local dest = ""
        local ok2, addr = pcall(function() return pkg.getAddress() end)
        if ok2 and addr and addr ~= "" then dest = " -> " .. addr end

        local timeStr = textutils.formatTime(os.time(), true)
        local content = #parts > 0 and table.concat(parts, ", ") or "(empty)"
        addLog(string.format("  [%s]%s %s", timeStr, dest, content))

        rednet.broadcast({ label = label, dest = dest, contents = parts }, "pkg_log")
    end
end
