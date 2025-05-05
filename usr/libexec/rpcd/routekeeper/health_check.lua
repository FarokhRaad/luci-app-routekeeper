local uci = require("uci").cursor()
local util = require("luci.util")

local M = {}

uci:load("routekeeper")

---------------------------------------------------------------------------------------------
-- Function: Load Settings from UCI
---------------------------------------------------------------------------------------------
function M.load_settings()
    uci:commit("routekeeper")  -- Ensure any pending changes are committed
    uci:unload("routekeeper")  -- Unload the old config from memory
    uci:load("routekeeper")    -- Load the latest config from disk

    local settings = uci:get_all("routekeeper", "global") or {}

    return {
        selected_default = settings.selected_default or "wan",
        curl_address = settings.curl_address or "http://www.gstatic.com/generate_204",
        ping_address = settings.ping_address or "8.8.8.8",
        curl_timeout = settings.curl_timeout or "2",
        curl_max_time = settings.curl_max_time or "2",
        ping_count = settings.ping_count or "1",
        ping_timeout = settings.ping_timeout or "1",
        test_type = settings.test_type or "both"
    }
end

---------------------------------------------------------------------------------------------
-- Function: Save Settings Efficiently
---------------------------------------------------------------------------------------------
function M.save_settings(new_settings)
    if type(new_settings) ~= "table" then
        return { success = false, error = "Invalid settings format" }
    end

    local section = "@global[0]"
    local updated = false

    local settings_data = new_settings.settings or new_settings  -- Handle both nested and flat inputs
    for key, new_value in pairs(settings_data) do
        local current_value = uci:get("routekeeper", section, key)

        if type(new_value) == "table" and next(new_value) == nil then
            new_value = nil
        end

        if new_value == "" then
            new_value = nil
        end

        if new_value ~= current_value then
            uci:set("routekeeper", section, key, new_value)
            updated = true
        end
    end


    if updated then
        uci:commit("routekeeper")
        return { success = true, message = "Settings updated successfully" }
    else
        return { success = true, message = "No changes detected" }
    end
end

---------------------------------------------------------------------------------------------
-- Function: Run Curl Test
---------------------------------------------------------------------------------------------
function M.run_ping_test(ifn)
    local settings = M.load_settings()
    if not ifn or ifn == "" then
        return { success = false, error = "Invalid interface name" }
    end

    local ping_cmd = string.format(
        "ping -c %s -W %s -I %s %s 2>&1",
        settings.ping_count, settings.ping_timeout, ifn, settings.ping_address
    )

    local output = util.trim(util.exec(ping_cmd))
    local rtt = output:match("time=([%d%.]+)") or output:match("time ([%d%.]+)")
    local rtt_num = tonumber(rtt)

    if not rtt_num then
        return { success = false, error = "Ping request failed", interface = ifn }
    end

    return {
        success = true,
        interface = ifn,
        ping_result = string.format("%d ms", math.floor(rtt_num))
    }
end
---------------------------------------------------------------------------------------------
-- Function: Run Ping Test
---------------------------------------------------------------------------------------------
function M.run_curl_test(ifn)
    local settings = M.load_settings()
    if not ifn or ifn == "" then
        return { success = false, error = "Invalid interface name" }
    end

    local curl_cmd = string.format(
        "curl --interface %q --connect-timeout %s --max-time %s -s -S -w '%%{time_total}\\n' -o /dev/null '%s'",
        ifn, settings.curl_timeout, settings.curl_max_time, settings.curl_address
    )

    local output = util.trim(util.exec(curl_cmd))
    local time_ms = tonumber(output)

    if not time_ms then
        return { success = false, error = "Curl request failed", interface = ifn }
    end

    return {
        success = true,
        interface = ifn,
        curl_result = string.format("%.0f ms", time_ms * 1000)
    }
end



return M
