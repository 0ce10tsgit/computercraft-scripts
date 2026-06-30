-- vault_tracker
-- Reads two Create vaults (left + right) and responds to rednet requests.
--
-- Commands received (as a table):
--   { cmd = "vault_highs" }  →  items where total count > CUTOFF
--   { cmd = "items"       }  →  items where total count >= CUTOFF (inclusive)

local MODEM_SIDE = "top"

rednet.open(MODEM_SIDE)

local function read_vaults()
    local totals = {}
    for _, side in ipairs({ "left", "right" }) do
        local vault = peripheral.wrap(side)
        if not vault then
            print(string.format("  [vault:%s] not found", side))
        else
            print(string.format("  [vault:%s] type=%s", side, peripheral.getType(side)))
            local ok, result = pcall(function() return vault.list() end)
            if not ok then
                print(string.format("  [vault:%s] list() error: %s", side, tostring(result)))
            elseif not result then
                print(string.format("  [vault:%s] list() returned nil", side))
            else
                local slot_count, item_count = 0, 0
                for k, stack in pairs(result) do
                    slot_count = slot_count + 1
                    local name = stack.name
                    if name then
                        item_count = item_count + 1
                        totals[name] = (totals[name] or 0) + (stack.count or 0)
                    else
                        print(string.format("  [vault:%s] slot %s has no name: %s", side, tostring(k), textutils.serialize(stack)))
                    end
                end
                print(string.format("  [vault:%s] slots=%d named=%d", side, slot_count, item_count))
            end
        end
    end
    local total_types = 0
    for _ in pairs(totals) do total_types = total_types + 1 end
    print(string.format("  [vaults] %d distinct item types aggregated", total_types))
    return totals
end

local function filter(totals, n, strict)
    local out = {}
    for name, count in pairs(totals) do
        if strict and count > n then
            out[name] = count
        elseif not strict and count >= n then
            out[name] = count
        end
    end
    return out
end

local PROTOCOL = "vault_net"
local CUTOFF   = 5

while true do
    local sender, msg, proto = rednet.receive()
    print(string.format("[rx] from=%d proto=%s type=%s", sender, tostring(proto), type(msg)))
    if proto ~= PROTOCOL then
        print(string.format("  [skip] wrong protocol: %s", tostring(proto)))
    elseif type(msg) == "table" then
        local totals = read_vaults()
        local reply

        if msg.cmd == "vault_highs" then
            reply = { ok = true, items = filter(totals, CUTOFF, true) }
        elseif msg.cmd == "items" then
            reply = { ok = true, items = filter(totals, CUTOFF, false) }
        end

        if reply then
            local n = 0
            for _ in pairs(reply.items) do n = n + 1 end
            print(string.format("  [tx] sending %d items to %d", n, sender))
            rednet.broadcast(reply, PROTOCOL)
        end
    else
        print(string.format("  [skip] bad msg: cmd=%s n=%s", tostring(msg and msg.cmd), tostring(msg and msg.n)))
    end
end
