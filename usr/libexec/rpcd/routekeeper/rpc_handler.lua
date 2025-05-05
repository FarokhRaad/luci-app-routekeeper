#!/usr/bin/lua

package.path = package.path .. ";/usr/libexec/rpcd/routekeeper/?.lua"

local ubus = require("ubus")
local uloop = require("uloop")

local iface = require("iface")
local gateway_switch = require("gateway_switch")
local health_check = require("health_check")

uloop.init()

local conn = ubus.connect()
if not conn then os.exit(1) end


local routekeeper_api = {

    -- Get list of interfaces
    get_interfaces = {
        function(req, msg)
            conn:reply(req, iface.get_interfaces())
        end, {}
    },

    -- Find active default interface
    find_active_default_if = {
        function(req, msg)
            conn:reply(req, iface.find_active_default_if())
        end, {}
    },

    -- Set default gateway
    set_default_gateway = {
        function(req, msg)
            if not msg.interface then
                conn:reply(req, { success = false, error = "Missing parameter: interface" })
                return
            end
            conn:reply(req, gateway_switch.set_default_gateway(msg.interface))
        end, { interface = ubus.STRING }
    },

    -- Run Curl test for an interface
    run_curl_test = {
        function(req, msg)
            if not msg.interface then
                conn:reply(req, { success = false, error = "Missing parameter: interface" })
                return
            end
            conn:reply(req, health_check.run_curl_test(msg.interface))
        end, { interface = ubus.STRING }
    },

    -- Run Ping test for an interface
    run_ping_test = {
        function(req, msg)
            if not msg.interface then
                conn:reply(req, { success = false, error = "Missing parameter: interface" })
                return
            end
            conn:reply(req, health_check.run_ping_test(msg.interface))
        end, { interface = ubus.STRING }
    },

    -- Load settings from UCI
    load_settings = {
        function(req, msg)
            conn:reply(req, { success = true, settings = health_check.load_settings() })
        end, {}
    },

    -- Save settings to UCI
    save_settings = {
        function(req, msg)
            if not msg.settings then
                conn:reply(req, { success = false, error = "Missing parameter: settings" })
                return
            end
            conn:reply(req, health_check.save_settings(msg.settings))
        end, { settings = ubus.TABLE }
    }
}

conn:add({ ["luci.routekeeper"] = routekeeper_api })
uloop.run()
