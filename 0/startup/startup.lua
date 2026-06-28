-- startup.lua — computer 0, package log aggregator
-- Receives pkg_log broadcasts from farm relay computers over the wired cable network.

local MODEM_SIDE = "left"

rednet.open(MODEM_SIDE)
print("Aggregator online, listening for farm relays...")

while true do
    local senderID, msg = rednet.receive("pkg_log")
    if type(msg) == "table" and msg.contents then
        local timeStr = textutils.formatTime(os.time(), true)
        local label   = (msg.label and msg.label ~= "") and msg.label or ("relay#" .. senderID)
        local dest    = (msg.dest  and msg.dest  ~= "") and (" -> " .. msg.dest) or ""
        local content = #msg.contents > 0 and table.concat(msg.contents, ", ") or "(empty)"
        print(string.format("[%s] %s%s | %s", timeStr, label, dest, content))
    end
end
