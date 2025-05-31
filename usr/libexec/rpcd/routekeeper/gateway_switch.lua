local uci = require("uci").cursor()
local util = require("luci.util")

local M = {}

uci:load("network")

local ROUTE_TABLE = "activegateway"
local ROUTE_RULE = "ip rule add iif br-lan priority 1100 lookup " .. ROUTE_TABLE
local ROUTE_RULE_CHECK = "ip rule show | grep 'lookup " .. ROUTE_TABLE .. "'"

--------------------------------------------------------------------------------
-- Ensure IP rule exists (one-time setup)
--------------------------------------------------------------------------------
local function ensure_ip_rule()
    local check = util.exec(ROUTE_RULE_CHECK)
    if not check or check == "" then
        util.exec(ROUTE_RULE)
    end
end

--------------------------------------------------------------------------------
-- Flush existing default route in the custom table
--------------------------------------------------------------------------------
local function flush_activegateway_table()
    util.exec("ip route flush table " .. ROUTE_TABLE)
end

--------------------------------------------------------------------------------
-- Generate custom route command for interface in activegateway table
--------------------------------------------------------------------------------
function M.get_custom_route_cmd(ifn)
    if not ifn or ifn == "" then
        return nil, "Invalid interface name"
    end

    local proto = uci:get("network", ifn, "proto") or ""
    local gw = uci:get("network", ifn, "gateway") or ""

    if proto == "static" and gw ~= "" then
        return string.format("ip route replace default via %s dev %s table %s", gw, ifn, ROUTE_TABLE)
    else
        return string.format("ip route replace default dev %s table %s", ifn, ROUTE_TABLE)
    end
end

--------------------------------------------------------------------------------
-- Set default gateway for LAN clients via custom routing table
--------------------------------------------------------------------------------
function M.set_default_gateway(ifn)
    if not ifn or ifn == "" then
        return { success = false, error = "Invalid interface name" }
    end

    ensure_ip_rule()
    flush_activegateway_table()

    local route_cmd, err = M.get_custom_route_cmd(ifn)
    if not route_cmd then
        return { success = false, error = err or "Failed to generate route command" }
    end

    local success = util.exec(route_cmd)

    if success then
        if not uci:get("routekeeper", "global") then
            uci:section("routekeeper", "global", "global", {})
        end
        uci:set("routekeeper", "global", "selected_default", ifn)
        uci:commit("routekeeper")

        return { success = true, message = "ActiveGateway route updated", interface = ifn }
    else
        return { success = false, error = "Failed to apply route command" }
    end
end

return M
