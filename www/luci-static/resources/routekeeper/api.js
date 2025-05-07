'use strict';

'require rpc';

// Declare RPC methods
var getInterfaces = rpc.declare({
    object: 'luci.routekeeper',
    method: 'get_interfaces',
    expect: { interfaces: [] }
});

var getDefaultGateway = rpc.declare({
    object: 'luci.routekeeper',
    method: 'find_active_default_if',
    expect: { default_interface: "" }
});

var setDefaultGateway = rpc.declare({
    object: 'luci.routekeeper',
    method: 'set_default_gateway',
    params: ['interface'],
    expect: { success: false }
});

var runPingTest = rpc.declare({
    object: 'luci.routekeeper',
    method: 'run_ping_test',
    params: ['interface']
});

var runCurlTest = rpc.declare({
    object: 'luci.routekeeper',
    method: 'run_curl_test',
    params: ['interface']
});

var runPingTestAll = rpc.declare({
    object: 'luci.routekeeper',
    method: 'run_ping_test_all'
});

var runCurlTestAll = rpc.declare({
    object: 'luci.routekeeper',
    method: 'run_curl_test_all'
});

var loadSettings = rpc.declare({
    object: 'luci.routekeeper',
    method: 'load_settings',
    expect: { settings: {} }
});

var saveSettings = rpc.declare({
    object: 'luci.routekeeper',
    method: 'save_settings',
    params: ['settings'],

});


// Export API functions
return L.Class.extend({
    getInterfaces: getInterfaces,
    getDefaultGateway: getDefaultGateway,
    setDefaultGateway: setDefaultGateway,
    runPingTest: runPingTest,
    runCurlTest: runCurlTest,
    runPingTestAll: runPingTestAll,
    runCurlTestAll: runCurlTestAll,
    loadSettings: loadSettings,
    saveSettings: saveSettings
});
