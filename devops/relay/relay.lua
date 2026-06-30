-- startup.lua — farm relay computer
-- Set name once with: os.setComputerLabel("farm_name") then reboot.

rednet.open("top")

local W, H  = term.getSize()
local label = os.getComputerLabel() or ("relay#" .. os.getComputerID())

-- Centered bordered row
local function row(text)
    local inner = W - 4
    local pad   = math.max(0, inner - #text)
    return "# " .. string.rep(" ", math.floor(pad/2)) .. text .. string.rep(" ", math.ceil(pad/2)) .. " #"
end

-- W=51: inner=47, "# " + 11x"/!\ " + "/!\" + " #" = 2+44+3+2 = 51
local BANG = "# " .. string.rep("/!\\ ", 11) .. "/!\\" .. " #"
local SEP  = "# " .. string.rep("=", W - 4)  .. " #"
local EDGE = string.rep("#", W)

local screen = {
    EDGE,                                                    --  1
    BANG,                                                    --  2
    row(""),                                                 --  3
    row(">>> DO NOT INTERRUPT OR CLOSE <<<"),                --  4
    row(""),                                                 --  5
    BANG,                                                    --  6
    SEP,                                                     --  7
    row(""),                                                 --  8
    row("Relay ID : " .. os.getComputerID()),                --  9
    row("Name: " .. label),                                  -- 10
    row(""),                                                 -- 11
    row("closing this loses telemetry not auto restored"),   -- 12
    SEP,                                                     -- 13
    row(""),                                                 -- 14
    row("Q to exit relay mode"),                             -- 15
    row("I will flambe u if u do ts"),                       -- 16
    row(""),                                                 -- 17
    BANG,                                                    -- 18
    EDGE,                                                    -- 19
}

term.clear()
for i = 1, math.min(#screen, H) do
    term.setCursorPos(1, i)
    term.write(screen[i]:sub(1, W))
end

while true do
    local ev = { os.pullEventRaw() }

    if ev[1] == "terminate" then
        -- silently swallow

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
        if ok2 and addr and addr ~= "" then dest = addr end

        rednet.broadcast({ label = label, dest = dest, contents = parts }, "pkg_log")
    end
end
