local uci = require("uci").cursor()
local json = require("luci.jsonc")
local util = require("luci.util")
local ubus = require("ubus")

local M = {}

uci:load("network")

--------------------------------------------------------------------------------
-- Get all network interfaces that are currently up (excluding loopback and lan)
--------------------------------------------------------------------------------
function M.get_interfaces()
    local discovered_ifs = {}
    local conn = ubus.connect()

    if not conn then
        return { success = false, error = "Failed to connect to ubus" }
    end

    uci:foreach("network", "interface", function(sec)
        local iname = sec[".name"]

        if iname and iname ~= "loopback" and iname ~= "lan" then
            local status = conn:call("network.interface." .. iname, "status", {})
            if status and status.up then
                table.insert(discovered_ifs, iname)
            end
        end
    end)

    conn:close()

    return {
        success = true,
        interfaces = discovered_ifs
    }
end

--------------------------------------------------------------------------------
-- Get active default gateway from the custom 'activegateway' routing table
--------------------------------------------------------------------------------
function M.find_active_default_if()
    local output = util.trim(util.exec("ip -j route show table activegateway 2>/dev/null"))

    if not output or output == "" then
        return { success = false, error = "Failed to execute IP command" }
    end

    local routes = json.parse(output)
    if not routes or type(routes) ~= "table" then
        return { success = false, error = "Invalid route response" }
    end

    for _, route in ipairs(routes) do
        if route.dst == "default" and route.dev then
            return {
                success = true,
                default_interface = route.dev,
                source = "activegateway"
            }
        end
    end

    return { success = false, error = "No default route found in activegateway" }
end

return M
