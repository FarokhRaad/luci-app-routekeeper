# luci-app-routekeeper

📦 **RouteKeeper**

RouteKeeper is a lightweight OpenWRT utility for managing default routes and performing connectivity checks.

---

## ✨ Features

- Detects and lists all active network interfaces, excluding LAN and loopback  
- Runs ping and/or curl tests on each interface  
- Automatically sets the lowest-latency interface as the default route on boot  
- Provides both a LuCI (web) interface and a terminal TUI  
- Includes UCI config support and ubus RPC endpoints  
- Robust fallback logic — if all checks fail, it defaults to the `wan` interface  
