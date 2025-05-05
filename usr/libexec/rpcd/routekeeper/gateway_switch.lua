local uci = require("uci").cursor()
local util = require("luci.util")

local M = {}

uci:load("network")

--------------------------------------------------------------------------------
-- Generate Default Route Command for an Interface
--------------------------------------------------------------------------------
function M.get_default_route_cmd(ifn)
    if not ifn or ifn == "" then
        return nil, "Invalid interface name"
    end

    local proto = uci:get("network", ifn, "proto") or ""
    local gw = uci:get("network", ifn, "gateway") or ""

    if proto == "static" and gw ~= "" then
        return string.format("ip route replace default via %s dev %s", gw, ifn)
    else
        return string.format("ip route replace default dev %s", ifn)
    end
end

--------------------------------------------------------------------------------
-- Set Default Gateway and Persist It
--------------------------------------------------------------------------------
function M.set_default_gateway(ifn)
    if not ifn or ifn == "" then
        return { success = false, error = "Invalid interface name" }
    end

    local route_cmd, err = M.get_default_route_cmd(ifn)
    if not route_cmd then
        return { success = false, error = err or "Failed to generate route command" }
    end

    -- Execute the command to change the route
    local success = util.exec(route_cmd)

    if success then
        -- Ensure the "global" section exists
        if not uci:get("routekeeper", "global") then
            uci:section("routekeeper", "global", "global", {})
        end

        -- Persist Default Gateway in /etc/config/routekeeper
        uci:set("routekeeper", "global", "selected_default", ifn)
        uci:commit("routekeeper")

        return { success = true, message = "Default gateway updated and saved", interface = ifn }
    else
        return { success = false, error = "Failed to update route" }
    end
end

return M